#include "flutter_window.h"

#include <windows.h>
#include <bcrypt.h>
#include <wincrypt.h>
#include <shlobj.h>

#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iterator>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr char kSecureChannel[] = "devdesk/secure_secrets";
constexpr char kAtomicFileChannel[] = "devdesk/atomic_files";
constexpr char kWindowLifecycleChannel[] = "devdesk/window_lifecycle";

std::filesystem::path SecureDirectory() {
  PWSTR local_app_data = nullptr;
  const HRESULT result = SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr,
                                               &local_app_data);
  if (FAILED(result) || local_app_data == nullptr) {
    throw std::runtime_error("Local application data is unavailable");
  }
  std::filesystem::path directory(local_app_data);
  CoTaskMemFree(local_app_data);
  directory /= L"DevDesk";
  directory /= L"SecureSecrets";
  std::filesystem::create_directories(directory);
  return directory;
}

std::string Sha256HexKey(const std::string& key) {
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  BCRYPT_HASH_HANDLE hash = nullptr;
  DWORD object_size = 0;
  DWORD hash_size = 0;
  DWORD copied = 0;
  std::vector<unsigned char> hash_object;
  std::vector<unsigned char> digest;

  auto cleanup = [&]() {
    if (hash != nullptr) BCryptDestroyHash(hash);
    if (algorithm != nullptr) BCryptCloseAlgorithmProvider(algorithm, 0);
  };
  try {
    if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM,
                                    nullptr, 0) < 0 ||
        BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH,
                          reinterpret_cast<PUCHAR>(&object_size),
                          sizeof(object_size), &copied, 0) < 0 ||
        BCryptGetProperty(algorithm, BCRYPT_HASH_LENGTH,
                          reinterpret_cast<PUCHAR>(&hash_size),
                          sizeof(hash_size), &copied, 0) < 0) {
      throw std::runtime_error("Could not initialize protected key hash");
    }
    hash_object.resize(object_size);
    digest.resize(hash_size);
    if (BCryptCreateHash(algorithm, &hash, hash_object.data(), object_size,
                         nullptr, 0, 0) < 0 ||
        BCryptHashData(
            hash,
            reinterpret_cast<PUCHAR>(const_cast<char*>(key.data())),
            static_cast<ULONG>(key.size()), 0) < 0 ||
        BCryptFinishHash(hash, digest.data(), hash_size, 0) < 0) {
      throw std::runtime_error("Could not hash protected-storage key");
    }
  } catch (...) {
    cleanup();
    throw;
  }
  cleanup();

  std::ostringstream stream;
  stream << std::hex << std::setfill('0');
  for (const unsigned char byte : digest) {
    stream << std::setw(2) << static_cast<int>(byte);
  }
  return stream.str();
}

std::filesystem::path SecretPath(const std::string& key) {
  if (key.empty() || key.size() > 240) {
    throw std::invalid_argument("Invalid protected-storage key");
  }
  return SecureDirectory() / (Sha256HexKey(key) + ".bin");
}

std::vector<unsigned char> Protect(const std::string& value) {
  DATA_BLOB input{};
  input.pbData = reinterpret_cast<BYTE*>(
      const_cast<char*>(value.data()));
  input.cbData = static_cast<DWORD>(value.size());
  DATA_BLOB output{};
  if (!CryptProtectData(&input, L"DevDesk protected workspace secrets", nullptr,
                        nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output)) {
    throw std::runtime_error("DPAPI protection failed");
  }
  std::vector<unsigned char> bytes(output.pbData,
                                   output.pbData + output.cbData);
  LocalFree(output.pbData);
  return bytes;
}

std::string Unprotect(const std::vector<unsigned char>& encrypted) {
  DATA_BLOB input{};
  input.pbData = const_cast<BYTE*>(encrypted.data());
  input.cbData = static_cast<DWORD>(encrypted.size());
  DATA_BLOB output{};
  if (!CryptUnprotectData(&input, nullptr, nullptr, nullptr, nullptr,
                          CRYPTPROTECT_UI_FORBIDDEN, &output)) {
    throw std::runtime_error("DPAPI unprotection failed");
  }
  std::string value(reinterpret_cast<char*>(output.pbData), output.cbData);
  LocalFree(output.pbData);
  return value;
}

void WriteProtected(const std::string& key, const std::string& value) {
  const auto target = SecretPath(key);
  const auto temporary = target.wstring() + L".tmp";
  const auto encrypted = Protect(value);
  {
    std::ofstream stream(std::filesystem::path(temporary),
                         std::ios::binary | std::ios::trunc);
    if (!stream) throw std::runtime_error("Could not open protected temp file");
    stream.write(reinterpret_cast<const char*>(encrypted.data()),
                 static_cast<std::streamsize>(encrypted.size()));
    stream.flush();
    if (!stream) throw std::runtime_error("Could not write protected temp file");
  }
  if (!MoveFileExW(temporary.c_str(), target.c_str(),
                   MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
    DeleteFileW(temporary.c_str());
    throw std::runtime_error("Could not replace protected value");
  }
}

std::optional<std::string> ReadProtected(const std::string& key) {
  const auto target = SecretPath(key);
  if (!std::filesystem::exists(target)) return std::nullopt;
  std::ifstream stream(target, std::ios::binary);
  if (!stream) throw std::runtime_error("Could not read protected value");
  std::vector<unsigned char> bytes(
      (std::istreambuf_iterator<char>(stream)), std::istreambuf_iterator<char>());
  if (bytes.empty()) throw std::runtime_error("Protected value is empty");
  return Unprotect(bytes);
}

void AtomicReplace(const std::string& temporary_utf8,
                   const std::string& target_utf8) {
  const std::filesystem::path temporary =
      std::filesystem::u8path(temporary_utf8);
  const std::filesystem::path target = std::filesystem::u8path(target_utf8);
  const DWORD attributes = GetFileAttributesW(target.c_str());
  if (attributes == INVALID_FILE_ATTRIBUTES ||
      (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
    throw std::runtime_error("Atomic replacement target is unavailable");
  }
  if ((attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
    throw std::runtime_error("Reparse targets are not replaced");
  }

  if (!ReplaceFileW(target.c_str(), temporary.c_str(), nullptr,
                    REPLACEFILE_WRITE_THROUGH, nullptr, nullptr)) {
    throw std::runtime_error("Atomic replacement failed");
  }
}

std::string RequiredString(const flutter::MethodCall<flutter::EncodableValue>& call,
                           const char* name) {
  const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
  if (arguments == nullptr) throw std::invalid_argument("Missing arguments");
  const auto found = arguments->find(flutter::EncodableValue(name));
  if (found == arguments->end()) throw std::invalid_argument("Missing argument");
  const auto* value = std::get_if<std::string>(&found->second);
  if (value == nullptr || value->empty()) {
    throw std::invalid_argument("Invalid argument");
  }
  return *value;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  secure_secret_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kSecureChannel,
          &flutter::StandardMethodCodec::GetInstance());
  secure_secret_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        try {
          if (call.method_name() == "isAvailable") {
            result->Success(flutter::EncodableValue(true));
            return;
          }
          if (call.method_name() == "write") {
            WriteProtected(RequiredString(call, "key"),
                           RequiredString(call, "value"));
            result->Success();
            return;
          }
          if (call.method_name() == "read") {
            const auto value = ReadProtected(RequiredString(call, "key"));
            if (value.has_value()) {
              result->Success(flutter::EncodableValue(value.value()));
            } else {
              result->Success();
            }
            return;
          }
          if (call.method_name() == "delete") {
            std::error_code error;
            std::filesystem::remove(SecretPath(RequiredString(call, "key")),
                                    error);
            if (error) throw std::runtime_error("Could not delete protected value");
            result->Success();
            return;
          }
          if (call.method_name() == "clearAll") {
            std::error_code error;
            std::filesystem::remove_all(SecureDirectory(), error);
            if (error) throw std::runtime_error("Could not clear protected values");
            result->Success();
            return;
          }
          result->NotImplemented();
        } catch (...) {
          result->Error("secure_store_failure",
                        "Protected storage operation failed.");
        }
      });

  window_lifecycle_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kWindowLifecycleChannel,
          &flutter::StandardMethodCodec::GetInstance());
  window_lifecycle_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        try {
          if (call.method_name() == "setDirty") {
            const auto* arguments =
                std::get_if<flutter::EncodableMap>(call.arguments());
            if (arguments == nullptr) throw std::invalid_argument("Missing arguments");
            const auto found = arguments->find(flutter::EncodableValue("dirty"));
            if (found == arguments->end()) throw std::invalid_argument("Missing dirty");
            const auto* dirty = std::get_if<bool>(&found->second);
            if (dirty == nullptr) throw std::invalid_argument("Invalid dirty");
            has_dirty_documents_ = *dirty;
            result->Success();
            return;
          }
          if (call.method_name() == "confirmClose") {
            has_dirty_documents_ = false;
            PostMessageW(GetHandle(), WM_CLOSE, 0, 0);
            result->Success();
            return;
          }
          result->NotImplemented();
        } catch (...) {
          result->Error("window_lifecycle_failure",
                        "The window close state could not be updated.");
        }
      });

  atomic_file_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kAtomicFileChannel,
          &flutter::StandardMethodCodec::GetInstance());
  atomic_file_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        try {
          if (call.method_name() == "replace") {
            AtomicReplace(RequiredString(call, "temporaryPath"),
                          RequiredString(call, "targetPath"));
            result->Success();
            return;
          }
          result->NotImplemented();
        } catch (...) {
          result->Error("atomic_replace_failure",
                        "The file could not be replaced atomically.");
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() { this->Show(); });
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_lifecycle_channel_.reset();
  atomic_file_channel_.reset();
  secure_secret_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_CLOSE:
      if (has_dirty_documents_ && window_lifecycle_channel_) {
        window_lifecycle_channel_->InvokeMethod(
            "closeRequested",
            std::make_unique<flutter::EncodableValue>());
        return 0;
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

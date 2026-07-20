#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // DPAPI-backed protected storage channel.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      secure_secret_channel_;

  // Same-directory Windows ReplaceFileW bridge for safe external saves.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      atomic_file_channel_;

  // Native close interception for unsaved document protection.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_lifecycle_channel_;
  bool has_dirty_documents_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_

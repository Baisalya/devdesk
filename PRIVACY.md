# Privacy Policy for DevDesk

Updated: 19 June 2026

DevDesk (“the app”) is committed to safeguarding your privacy. This policy explains what information is collected, how it is used and your choices. Because DevDesk is designed to work entirely offline, your personal data never leaves your device.

## 1. Information we do **not** collect

- **No personal data is transmitted**: DevDesk does not collect or transmit any personal information (such as your name, email, location or device identifiers) to servers or third parties. All data is kept locally on your device.
- **No analytics or tracking**: The app contains no analytics SDKs or third‑party tracking libraries. We do not track user behaviour, device information or usage statistics.
- **No remote storage**: Notes, API histories, environment variables and any other content you create remain stored locally in the app’s private storage. They are never uploaded to cloud services.

## 2. Information you provide

You may voluntarily enter data into the app, for example:

- **Notes and snippets**: The notes and snippets you write are saved locally using an on‑device database (Hive). You can delete individual notes or clear all data from the settings screen.
- **API requests**: When using the API tester, you input URLs, headers and request bodies. These are sent over the internet only to the specified endpoint when you tap the “Send” button. You can disable saving of authorization headers and tokens in the history settings.
- **Tokens and secrets**: JWT tokens are decoded locally in your browser; they are never transmitted over the network. We recommend exercising caution when pasting sensitive tokens and using the option not to store them.

## 3. Permissions

DevDesk requests minimal permissions. On Android, the app requires:

- **Internet**: to send API requests when you use the API tester. No internet connection is required for any other features.

No other permissions (such as storage access, location, contacts or camera) are requested or used.

## 4. Data export and import

You may export your local data (notes, API history, environment variables) to a JSON file for backup or transfer to another device. The exported file remains under your control and is not uploaded anywhere by the app. When importing a backup, the file remains on your device and is read only into the app’s local storage.

## 5. Deleting your data

You can delete any individual note or snippet within the app. The settings screen also provides a **Clear Data** option that will permanently remove all stored notes, API histories and configurations from the device. This action cannot be undone.

## 6. Changes to this policy

We may update this privacy policy from time to time. When we do, the updated policy will be available in the app repository. We recommend checking the policy whenever you update the app.

## 7. Contact

If you have any questions or concerns about privacy while using DevDesk, please open an issue in the repository or email the developer at the contact provided in the Play Store listing.
## External file handling

External files are opened only when the user chooses them. DevDesk processes those files locally and does not upload them. Android uses a system picker style flow and does not request broad storage access or `MANAGE_EXTERNAL_STORAGE`. Windows uses normal file dialogs. Editing an external file uses Save As/export copy unless the platform safely exposes a writable original path and the user confirms overwrite.

DevDesk warns before opening `.env` files because they commonly contain secrets. API collection imports default to stripping authorization, token, API key, and secret-like headers unless the user explicitly chooses to import them.

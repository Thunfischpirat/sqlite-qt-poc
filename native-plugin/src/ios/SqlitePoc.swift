import Foundation
#if canImport(Cordova)
import Cordova
#endif

@objc(SqlitePoc)
// Java: class SqlitePoc extends CordovaPlugin.
// iOS links the native libraries at build time instead of calling System.loadLibrary().
class SqlitePoc: CDVPlugin {
    // Java: execute(action, args, callback). On iOS, Cordova invokes run() directly;
    // command.callbackId identifies the JavaScript callback to receive the result.
    @objc func run(_ command: CDVInvokedUrlCommand) {
        do {
            // Java: new File(activity.getFilesDir(), "demo.sqlite").getPath().
            // Both platforms choose a database file inside the app's private storage.
            let directory: URL = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true)
            let path: String = directory.appendingPathComponent("demo.sqlite").path
            // Java: new JSONObject(nativeRun(path, driver)).
            // The iOS driver is linked into the app, so no driver path is needed.
            let result: [String: Any] = try runNativeDemo(path: path)
            // Java: result.has("error") followed by result.getString("error").
            let nativeError: String? = result["error"] as? String
            let response: CDVPluginResult
            if nativeError != nil {
                // Java: callback.error(errorMessage).
                response = CDVPluginResult(status: .error, messageAs: nativeError!)
            } else {
                // Java: callback.success(result).
                response = CDVPluginResult(status: .ok, messageAs: result)
            }
            // iOS sends the constructed result using the callback ID.
            self.commandDelegate.send(response, callbackId: command.callbackId)
        } catch {
            // Java: catch (Exception error) { callback.error(error.toString()); }.
            let response: CDVPluginResult = CDVPluginResult(status: .error,
                                           messageAs: error.localizedDescription)
            self.commandDelegate.send(response, callbackId: command.callbackId)
        }
    }

    // Encapsulates the equivalent of Java's new JSONObject(nativeRun(...)).
    // [String: Any] is the Swift dictionary used here to represent the JSON object.
    private func runNativeDemo(path: String) throws -> [String: Any] {
        // Java nativeRun() crosses JNI; this call uses the C interface to C++.
        let json: UnsafeMutablePointer<CChar>? = sqlitePocRun(path)
        if json == nil {
            throw NSError(domain: "SqlitePoc", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not allocate result"])
        }
        // JNI returns a managed Java String. Here we copy the C buffer into a
        // Swift String and explicitly free the buffer before parsing can throw.
        let jsonText: String = String(cString: json!)
        sqlitePocFree(json)
        let data: Data = Data(jsonText.utf8)
        // Java: new JSONObject(jsonText). Swift's JSON parser takes Data as input.
        let result: [String: Any]? = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if result == nil {
            throw NSError(domain: "SqlitePoc", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid native result"])
        }
        return result!
    }
}

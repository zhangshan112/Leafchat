import Foundation
import AdjustSdk

enum AdjustBuildEnvironment {
    static var sdkEnvironment: String {
        #if DEBUG
        return ADJEnvironmentSandbox
        #else
        return ADJEnvironmentProduction
        #endif
    }

}

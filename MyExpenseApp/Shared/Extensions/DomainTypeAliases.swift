import MyExpenseCore

/// SwiftUI also declares `Transaction`; this module-level alias makes the domain type win
/// in every app file that imports both modules.
typealias Transaction = MyExpenseCore.Transaction

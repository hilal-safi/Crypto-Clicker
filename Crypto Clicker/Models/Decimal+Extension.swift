//
//  Decimal+Extension.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-03.
//

import Foundation

extension Decimal {
    /// Rounds a Decimal down to the nearest whole number.
    func roundedDownToWhole() -> Decimal {
        let handler = NSDecimalNumberHandler(
            roundingMode: .down,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let nsDecimal = self as NSDecimalNumber
        return nsDecimal.rounding(accordingToBehavior: handler) as Decimal
    }
    
    /// Rounds a Decimal **up** to the nearest whole number.
    func roundedUpToWhole() -> Decimal {
        let handler = NSDecimalNumberHandler(
            roundingMode: .up,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let nsDecimal = self as NSDecimalNumber
        return nsDecimal.rounding(accordingToBehavior: handler) as Decimal
    }
}

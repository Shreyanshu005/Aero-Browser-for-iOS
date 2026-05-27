//
//  Comparable+Clamped.swift
//  Aero
//
//  Created on 2026-05-27.
//

import Foundation

extension Comparable {
    /// Returns `self` clamped to the given closed range.
    ///
    /// If `self` is below the range's lower bound, the lower bound is returned.
    /// If `self` is above the upper bound, the upper bound is returned.
    /// Otherwise, `self` is returned unchanged.
    ///
    /// - Parameter range: The closed range to clamp to.
    /// - Returns: The clamped value.
    ///
    /// ## Example
    /// ```swift
    /// let value = 15
    /// value.clamped(to: 0...10)  // returns 10
    /// value.clamped(to: 20...30) // returns 20
    /// value.clamped(to: 10...20) // returns 15
    /// ```
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

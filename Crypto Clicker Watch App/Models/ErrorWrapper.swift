//
//  ErrorWrapper.swift
//  Crypto Clicker Watch App
//
//  Created by Hilal Safi on 2025-01-15.
//

import Foundation

struct ErrorWrapper: Identifiable {
    let id: UUID
    let error: Error
    let guidance: String

    init(id: UUID = UUID(), error: Error, guidance: String) {
        self.id = id
        self.error = error
        self.guidance = guidance
    }
}

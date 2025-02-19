//
//  ErrorWrapper.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-09.
//

import Foundation

struct ErrorWrapper: Identifiable {
    
    let id: UUID
    let error: Error
    let guidance: String
    let title: String
    let date: Date
    let errorCode: Int?
    
    /// Initializes an ErrorWrapper with optional title, errorCode, and date.
    init(id: UUID = UUID(), error: Error, guidance: String, title: String = "An Error Occurred", errorCode: Int? = nil, date: Date = Date()) {
        self.id = id
        self.error = error
        self.guidance = guidance
        self.title = title
        self.errorCode = errorCode
        self.date = date
    }
    
    /// Returns a full description combining title, error details, guidance, and timestamp.
    func fullDescription() -> String {
        var description = "\(title)\n\(error.localizedDescription)"
        if let code = errorCode {
            description += "\nError Code: \(code)"
        }
        description += "\n\(guidance)"
        description += "\nOccurred on: \(date.formatted(date: .abbreviated, time: .shortened))"
        return description
    }
}

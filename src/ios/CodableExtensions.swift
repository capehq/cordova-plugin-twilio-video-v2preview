//
//  CodableExtensions.swift
//
//  Created by Naoki Hiroshima on 9/21/17.
//  Copyright (c) 2017 Cape Productions, Inc. All rights reserved.
//

import Foundation

extension Encodable {
    func toJSONData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try? encoder.encode(self)
    }

    func toJSONString() -> String? {
        guard let data = toJSONData(), let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    func toJSONDictionary() -> [String: Any]? {
        guard let data = toJSONData(), let dict = try? JSONSerialization.jsonObject(with: data, options: []) else { return nil }
        guard dict is NSDictionary else {
            fatalError("\(type(of: self)) is not encoded as Dictionary. Use toJSONString() instead")
        }
        return dict as? [String: Any]
    }
}

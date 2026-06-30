import Foundation

enum ShortcutKeyCode {
    static let leftCommand: UInt16 = 0x37
    static let rightCommand: UInt16 = 0x36
    static let leftOption: UInt16 = 0x3a
    static let rightOption: UInt16 = 0x3d
    static let leftShift: UInt16 = 0x38
    static let rightShift: UInt16 = 0x3c
    static let leftControl: UInt16 = 0x3b
    static let rightControl: UInt16 = 0x3e
    static let fn: UInt16 = 0x3f
    static let escape: UInt16 = 0x35
    static let space: UInt16 = 0x31

    static let functionKeyByCode: [UInt16: Int] = [
        0x7a: 1,
        0x78: 2,
        0x63: 3,
        0x76: 4,
        0x60: 5,
        0x61: 6,
        0x62: 7,
        0x64: 8,
        0x65: 9,
        0x6d: 10,
        0x67: 11,
        0x6f: 12,
        0x69: 13,
        0x6b: 14,
        0x71: 15,
        0x6a: 16,
        0x40: 17,
        0x4f: 18,
        0x50: 19,
        0x5a: 20,
    ]
}

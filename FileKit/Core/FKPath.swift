//
//  FKPath.swift
//  FileKit
//
//  The MIT License (MIT)
//
//  Copyright (c) 2015 Nikolai Vazquez
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

/// A representation of a filesystem path.
///
/// An FKPath instance lets you manage files in a much easier way.
///
public struct FKPath: StringLiteralConvertible,
                      RawRepresentable,
                      Hashable,
                      Indexable,
                      CustomStringConvertible,
                      CustomDebugStringConvertible {
    
    // MARK: - FKPath
    
    /// The standard separator for path components.
    public static let Separator = "/"
    
    /// The path of the program's current working directory.
    public static var Current: FKPath {
        get {
            return FKPath(NSFileManager.defaultManager().currentDirectoryPath)
        }
        set {
            NSFileManager.defaultManager().changeCurrentDirectoryPath(newValue._path)
        }
    }
    
    /// The stored path property.
    private var _path: String
    
    /// The components of the path.
    public var components: [FKPath] {
        var result = [FKPath]()
        for (index, component) in (_path as NSString).pathComponents.enumerate()
        {
            if index == 0 || component != "/" {
                result.append(FKPath(component))
            }
        }
        return result
    }
    
    /// A new path created by removing extraneous components from the path.
    public var standardized: FKPath {
        return FKPath((self._path as NSString).stringByStandardizingPath)
    }
    
    /// A new path created by resolving all symlinks and standardizing the path.
    public var resolved: FKPath {
        return FKPath((self._path as NSString).stringByResolvingSymlinksInPath)
    }
    
    /// A new path created by making the path absolute.
    ///
    /// If the path begins with "`/`", then the standardized path is returned.
    /// Otherwise, the path is assumed to be relative to the current working
    /// directory and the standardized version of the path added to the current
    /// working directory is returned.
    ///
    public var absolute: FKPath {
        return self.isAbsolute
            ? self.standardized
            : (FKPath.Current + self).standardized
    }
    
    /// Returns true if the path begins with "`/`".
    public var isAbsolute: Bool {
        return _path.hasPrefix(FKPath.Separator)
    }
    
    /// Returns true if the path does not begin with "`/`".
    public var isRelative: Bool {
        return !isAbsolute
    }
    
    /// Returns true if a file exists at the path.
    public var exists: Bool {
        return NSFileManager.defaultManager().fileExistsAtPath(_path)
    }
    
    /// Returns true if the path points to a directory.
    public var isDirectory: Bool {
        var isDirectory: ObjCBool = false
        return NSFileManager.defaultManager()
            .fileExistsAtPath(_path, isDirectory: &isDirectory) && isDirectory
    }
    
    /// The path's extension.
    public var pathExtension: String {
        return (rawValue as NSString).pathExtension
    }
    
    /// The path's parent path.
    public var parent: FKPath {
        return FKPath((_path as NSString).stringByDeletingLastPathComponent)
    }
    
    /// The path's children paths.
    public var children: [FKPath] {
        if let paths = try? NSFileManager.defaultManager().contentsOfDirectoryAtPath(_path) {
            return paths.map { self + FKPath($0) }
        }
        return []
    }
    
    /// Initializes a path to "`/`".
    public init() {
        _path = "/"
    }
    
    /// Initializes a path to the string's value.
    public init(_ path: String) {
        self._path = path
    }
    
    /// Find paths in `self` that match a condition.
    ///
    /// - Parameters:
    ///     - searchDepth: How deep to search before exiting.
    ///     - condition: If `true`, the path is added.
    ///
    public func findPaths(searchDepth depth: Int, condition: (FKPath) -> Bool) -> [FKPath] {
        var paths = [FKPath]()
        for child in self.children {
            if condition(child) {
                paths.append(child)
            } else if depth != 0 {
                paths += child.findPaths(searchDepth: depth - 1, condition: condition)
            }
        }
        return paths
    }
    
    /// Standardizes the path.
    public mutating func standardize() {
        self = self.standardized
    }
    
    /// Resolves the path's symlinks and standardizes it.
    public mutating func resolve() {
        self = self.resolved
    }
    
    /// Creates a symbolic link at a path that points to `self`.
    ///
    /// If the symbolic link path already exists and _is not_ a directory, an
    /// error will be thrown and a link will not be created.
    ///
    /// If the symbolic link path already exists and _is_ a directory, the link
    /// will be made to a file in that directory.
    ///
    /// - Throws: `FKError.FileDoesNotExist`, `FKError.CreateSymlinkFail`
    ///
    public func symlinkFileToPath(var path: FKPath) throws {
        if self.exists {
            if path.exists && !path.isDirectory {
                throw FKError.CreateSymlinkFail
            } else if path.isDirectory && !self.isDirectory {
                path += self.components.last!
            }
            do {
                let manager = NSFileManager.defaultManager()
                try manager.createSymbolicLinkAtPath(
                    path._path, withDestinationPath: self._path)
            } catch {
                throw FKError.CreateSymlinkFail
            }
        } else {
            throw FKError.FileDoesNotExist
        }
    }
    
    /// Creates a file at path.
    ///
    /// Throws an error if the file cannot be created.
    ///
    /// - Throws: `FKError.CreateFileFail`
    ///
    public func createFile() throws {
        let manager = NSFileManager.defaultManager()
        if !manager.createFileAtPath(_path, contents: nil, attributes: nil) {
            throw FKError.CreateFileFail
        }
    }
    
    /// Creates a directory at the path.
    ///
    /// Throws an error if the directory cannot be created.
    ///
    /// - Throws: `FKError.CreateFileFail`
    ///
    public func createDirectory() throws {
        do {
            let manager = NSFileManager.defaultManager()
            try manager.createDirectoryAtPath(
                _path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw FKError.CreateFileFail
        }
    }
    
    /// Deletes the file or directory at the path.
    ///
    /// Throws an error if the file or directory cannot be deleted.
    ///
    /// - Throws: `FKError.DeleteFileFail`
    ///
    public func deleteFile() throws {
        do {
            let manager = NSFileManager.defaultManager()
            try manager.removeItemAtPath(_path)
        } catch {
            throw FKError.DeleteFileFail
        }
    }
    
    /// Moves the file at `self` to a path.
    ///
    /// Throws an error if the file cannot be moved.
    ///
    /// - Throws: `FKError.FileDoesNotExist`, `FKError.MoveFileFail`
    ///
    public func moveFileToPath(path: FKPath) throws {
        if self.exists {
            if !path.exists {
                do {
                    let manager = NSFileManager.defaultManager()
                    try manager.moveItemAtPath(self.rawValue, toPath: path.rawValue)
                } catch {
                    throw FKError.MoveFileFail
                }
            } else {
                throw FKError.MoveFileFail
            }
        } else {
            throw FKError.FileDoesNotExist
        }
    }
    
    /// Copies the file at `self` to a path.
    ///
    /// Throws an error if the file at `self` could not be copied or if a file
    /// already exists at the destination path.
    ///
    /// - Throws: `FKError.FileDoesNotExist`, `FKError.CopyFileFail`
    ///
    public func copyFileToPath(path: FKPath) throws {
        if self.exists {
            if !path.exists {
                do {
                    let manager = NSFileManager.defaultManager()
                    try manager.copyItemAtPath(self.rawValue, toPath: path.rawValue)
                } catch {
                    throw FKError.CopyFileFail
                }
            } else {
                throw FKError.CopyFileFail
            }
        } else {
            throw FKError.FileDoesNotExist
        }
    }
    
    // MARK: - StringLiteralConvertible
    
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    
    public typealias UnicodeScalarLiteralType = StringLiteralType
    
    /// Initializes a path to the literal.
    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        _path = value
    }
    
    /// Initializes a path to the literal.
    public init(stringLiteral value: StringLiteralType) {
        _path = value
    }
    
    /// Initializes a path to the literal.
    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        _path = value
    }
    
    // MARK: - RawRepresentable
    
    /// Initializes a path to the string value.
    public init(rawValue: String) {
        _path = rawValue
    }
    
    /// The path's string value.
    public var rawValue: String {
        return _path
    }
    
    // MARK: - Hashable
    
    /// The hash value of the path.
    public var hashValue: Int {
        return _path.hashValue
    }
    
    // MARK: - Indexable
    
    /// The path's start index.
    public var startIndex: Int {
        return components.startIndex
    }
    
    /// The path's end index; the successor of the last valid subscript argument.
    public var endIndex: Int {
        return components.endIndex
    }
    
    /// The path's subscript. (read-only)
    ///
    /// - Returns: All of the path's elements up to and including the index.
    ///
    public subscript(index: Int) -> FKPath {
        if index < 0 || index >= components.count {
            fatalError("FKPath index out of range")
        } else {
            var result = components.first!
            for i in 1 ..< index + 1 {
                result += components[i]
            }
            return result
        }
    }
    
    // MARK: - CustomStringConvertible
    
    /// A textual representation of `self`.
    public var description: String {
        return _path
    }
    
    // MARK: - CustomDebugStringConvertible
    
    /// A textual representation of `self`, suitable for debugging.
    public var debugDescription: String {
        return String(self.dynamicType) + ": " + _path.debugDescription
    }
    
}

// MARK: - FKPaths

extension FKPath {
    
    /// Returns the path to the user's or application's home directory,
    /// depending on the platform.
    public static var UserHome: FKPath {
        return FKPath(NSHomeDirectory())
    }
    
    /// Returns the path to the user's temporary directory.
    public static var UserTemporary: FKPath {
        return FKPath(NSTemporaryDirectory())
    }
    
    /// Returns the path to the user's caches directory.
    public static var UserCaches: FKPath {
        return pathInUserDomain(.CachesDirectory)
    }
    
    #if os(OSX)
    
    /// Returns the path to the user's applications directory.
    public static var UserApplications: FKPath {
        return pathInUserDomain(.ApplicationDirectory)
    }
    
    /// Returns the path to the user's application support directory.
    public static var UserApplicationSupport: FKPath {
        return pathInUserDomain(.ApplicationSupportDirectory)
    }
    
    /// Returns the path to the user's desktop directory.
    public static var UserDesktop: FKPath {
        return pathInUserDomain(.DesktopDirectory)
    }
    
    /// Returns the path to the user's documents directory.
    public static var UserDocuments: FKPath {
        return pathInUserDomain(.DocumentDirectory)
    }
    
    /// Returns the path to the user's downloads directory.
    public static var UserDownloads: FKPath {
        return pathInUserDomain(.DownloadsDirectory)
    }
    
    /// Returns the path to the user's library directory.
    public static var UserLibrary: FKPath {
        return pathInUserDomain(.LibraryDirectory)
    }
    
    /// Returns the path to the user's movies directory.
    public static var UserMovies: FKPath {
        return pathInUserDomain(.MoviesDirectory)
    }
    
    /// Returns the path to the user's music directory.
    public static var UserMusic: FKPath {
        return pathInUserDomain(.MusicDirectory)
    }
    
    /// Returns the path to the user's pictures directory.
    public static var UserPictures: FKPath {
        return pathInUserDomain(.PicturesDirectory)
    }
    
    /// Returns the path to the system's applications directory.
    public static var SystemApplications: FKPath {
        return pathInSystemDomain(.ApplicationDirectory)
    }
    
    /// Returns the path to the system's application support directory.
    public static var SystemApplicationSupport: FKPath {
        return pathInSystemDomain(.ApplicationSupportDirectory)
    }
    
    /// Returns the path to the system's library directory.
    public static var SystemLibrary: FKPath {
        return pathInSystemDomain(.LibraryDirectory)
    }
    
    /// Returns the path to the system's core services directory.
    public static var SystemCoreServices: FKPath {
        return pathInSystemDomain(.CoreServiceDirectory)
    }
    
    #endif
    
    private static func pathInUserDomain(directory: NSSearchPathDirectory) -> FKPath {
        return pathsInDomains(directory, .UserDomainMask)[0]
    }
    
    private static func pathInSystemDomain(directory: NSSearchPathDirectory) -> FKPath {
        return pathsInDomains(directory, .SystemDomainMask)[0]
    }
    
    private static func pathsInDomains(directory: NSSearchPathDirectory,
        _ domainMask: NSSearchPathDomainMask) -> [FKPath] {
            let paths = NSSearchPathForDirectoriesInDomains(directory, domainMask, true)
            return paths.map { FKPath($0) }
    }
    
}



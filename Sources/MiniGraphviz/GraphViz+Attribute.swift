extension GraphViz {
    /// Typealias for a collection of attributes for a node, connection, or subgraph.
    public typealias Attributes = [String: AttributeValue]

    /// An attribute for a node or connection in a graphviz node.
    public enum AttributeValue: Equatable, CustomStringConvertible, ExpressibleByStringLiteral, ExpressibleByFloatLiteral, ExpressibleByStringInterpolation {
        case double(Double)
        case string(String)
        case raw(String)

        public var description: String {
            switch self {
            case .double(let value):
                return value.description
            case .raw(let value):
                return value
            case .string(let value):
                return value.debugDescription
            }
        }

        /// Raw string value for the contents of this node, with no special characters
        /// for printing in .dot files.
        public var rawValue: String {
            switch self {
            case .double(let value):
                return value.description

            case .string(let value), .raw(let value):
                return value
            }
        }

        public init(stringLiteral value: String) {
            self = .raw(value)
        }

        public init(floatLiteral value: Double) {
            self = .double(value)
        }
    }
}

internal extension GraphViz.Attributes {
    /// Returns a dot file-compatible list of attributes from this attributes
    /// dictionary, enclosed between square brackets.
    ///
    /// - Parameter defaultValues: A dictionary of default values, where if a
    /// key within `self` matches the value of the same key on this dictionary
    /// the value is not emitted.
    /// - Returns: A string representation of this list of attributes, enclosed
    /// within square brackets.
    func toDotFileString(defaultValues: Self = [:]) -> String {
        let attrList = _dotFileString(defaultValues: defaultValues, separated: false)
        if attrList.isEmpty { return "" }
        return "[" + attrList.joined(separator: ", ") + "]"
    }

    /// Returns a dot file-compatible list of attributes from this attributes
    /// dictionary, separated and terminated by semi-colons, fit to be used in
    /// a graph definition.
    ///
    /// - Parameter defaultValues: A dictionary of default values, where if a
    /// key within `self` matches the value of the same key on this dictionary
    /// the value is not emitted.
    /// - Returns: A string representation of this list of attributes, terminated
    /// with semicolons.
    func toInlineDotFileString(defaultValues: Self = [:]) -> String {
        let attrList = _dotFileString(defaultValues: defaultValues, separated: true)
        return attrList.joined(separator: "; ")
    }

    func _dotFileString(defaultValues: Self, separated: Bool) -> [String] {
        // Knock down default values
        var reduced: Self = self

        for (key, value) in defaultValues {
            if reduced[key] == value {
                reduced.removeValue(forKey: key)
            }
        }

        if reduced.isEmpty {
            return []
        }

        var attrList: [String] = []

        for key in reduced.keys.sorted() {
            guard let value = reduced[key] else { continue }

            if separated {
                attrList.append("\(key) = \(value)")
            } else {
                attrList.append("\(key)=\(value)")
            }
        }

        return attrList
    }
}

import Foundation

/// Class for generating Graphviz visualizations of undirected or directed graphs.
public class GraphViz {
    public typealias NodeId = Int

    private static let attribute_rankdir = "rankdir"

    private static func _defaultGraphAttributes() -> Attributes {
        return [
            attribute_rankdir: .raw(RankDir.topToBottom.rawValue)
        ]
    }

    private var _nextId: Int = 1
    private var _rootGroup: Group

    /// The name for the root graph/digraph.
    /// If `nil`, no name is given to the root graph.
    public var rootGraphName: String?

    /// Rank direction for this graph.
    ///
    /// Defaults to `.leftToRight`.
    public var rankDir: RankDir {
        get {
            guard let value = attributes[Self.attribute_rankdir]?.rawValue else {
                return .leftToRight
            }
            guard let rankDir = RankDir(rawValue: value) else {
                return .leftToRight
            }

            return rankDir
        }
        set {
            attributes[Self.attribute_rankdir] = .raw(newValue.rawValue)
        }
    }

    /// Attributes for this graph.
    public var attributes: Attributes = [:]

    public init(rootGraphName: String? = nil) {
        self.rootGraphName = rootGraphName

        _rootGroup = Group(title: nil, kind: .root)
    }

    private func _graphAttributes() -> Attributes {
        var result = attributes
        result[Self.attribute_rankdir] = .raw(rankDir.rawValue)

        return result
    }

    /// Generates a .dot file for visualization.
    public func generateFile(options: Options = .default) -> String {
        let simplified =
            options.simplifyGroups ? _rootGroup.simplify() : _rootGroup

        let out = StringOutput()

        var graphLabel = "digraph"
        if let rootGraphName {
            graphLabel += " \(rootGraphName)"
        }

        out(beginBlock: graphLabel) {
            let spacer = out.spacerToken(disabled: true)

            let attr =
                _graphAttributes()
                    .toDotFileString(
                        defaultValues: Self._defaultGraphAttributes()
                    )

            if !attr.isEmpty {
                out(line: "graph \(attr)")

                spacer.reset()
            }

            var clusterCounter = 0
            simplified.generateGraph(
                in: out,
                options: options,
                spacer: spacer,
                clusterCounter: &clusterCounter
            )
        }

        return out.buffer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns the first node ID whose label matches the given textual label.
    public func nodeId(forLabel label: String) -> NodeId? {
        _rootGroup.findNodeId(label: label)
    }

    /// Creates a new node with a given label and (optionally) attributes,
    /// nested within a given set of groups.
    ///
    /// - note: 'label' attribute in `attributes` dictionary is overwritten by
    /// `label` provided.
    @discardableResult
    public func createNode(
        label: String,
        groups: [String] = [],
        attributes: Attributes = [:]
    ) -> NodeId {

        defer { _nextId += 1 }

        let id = _nextId

        var node = Node(id: id)
        node.attributes = attributes
        node.label = label

        _rootGroup.getOrCreateGroup(groups).addNode(node)

        return node.id
    }

    /// Returns the first node ID whose label matches the given textual label,
    /// or generates as new node ID with the given label, in case it does not exist.
    public func getOrCreate(label: String) -> NodeId {
        if let id = nodeId(forLabel: label) {
            return id
        }

        let id = createNode(label: label)

        return id
    }

    /// Sets attributes for a specified node ID.
    /// Note that this does not change the attribute for the label of the node.
    public func setAttributes(forNodeId nodeId: NodeId, _ attributes: Attributes) {
        withNodeId(nodeId) { node in
            let label = node.label

            node.attributes = attributes
            node.label = label
        }
    }

    /// Adds a connection between two nodes whose labels match the given labels.
    /// If nodes with the given labels do not exist, they are created first on
    /// the root group.
    public func addConnection(
        fromLabel: String,
        toLabel: String,
        label: String? = nil,
        color: String? = nil,
        attributes: Attributes = [:]
    ) {

        let from = getOrCreate(label: fromLabel)
        let to = getOrCreate(label: toLabel)

        addConnection(
            from: from,
            to: to,
            label: label,
            color: color,
            attributes: attributes
        )
    }

    /// Adds a connection between two node IDs.
    public func addConnection(
        from: NodeId,
        to: NodeId,
        label: String? = nil,
        color: String? = nil,
        attributes: Attributes = [:]
    ) {

        var connection = Connection(
            idFrom: from,
            idTo: to
        )

        connection.attributes = attributes
        connection.label = label
        connection.color = color

        _rootGroup.addConnection(connection)
    }

    /// Adds a connection between two node IDs with a specified set of attributes.
    public func addConnection(
        from: NodeId,
        to: NodeId,
        attributes: Attributes
    ) {

        let connection = Connection(
            idFrom: from,
            idTo: to,
            attributes: attributes
        )

        _rootGroup.addConnection(connection)
    }

    /// Ranks all nodes with a given ID as the next available lowest rank.
    /// This pushes the nodes onto a new group in their common ancestor, containing
    /// the rank.
    ///
    /// If a node in the sequence already belongs to a rank, it is removed from
    /// that rank first.
    public func groupAsRank(_ ids: some Sequence<NodeId>, rank: Rank) {
        let ids = Array(ids)

        // Start by pulling all nodes to the closest ancestor
        _rootGroup.moveNodesToCommonAncestor(ids)
        guard let group = _rootGroup.findGroupForNode(id: ids[0]) else {
            return
        }

        let rankGroup = Group(title: nil, kind: .anonymous)
        rankGroup.attributes["rank"] = .string(rank.rawValue)

        let nodes = group.removeNodes(ids, removeConnections: false)
        rankGroup.addNodes(nodes)

        group.addSubgroup(rankGroup)
    }

    @discardableResult
    private func withNodeId(_ nodeId: NodeId, _ closure: (inout Node) -> Void) -> Bool {
        _rootGroup.withNodeId(nodeId, closure)
    }

    /// Specifies a type of rank for groups of nodes.
    public enum Rank: String {
        /// All nodes are placed on the same rank.
        case same

        /// All nodes are placed on the minimum rank.
        case min

        /// All nodes are placed on the minimum rank, and the only nodes on the
        /// minimum rank belong to some subgraph with `rank="source"` or `rank="min"`.
        case source

        /// All nodes are placed on the minimum rank, and the only nodes on the
        /// minimum rank belong to some subgraph with `rank="source"` or `rank="min"`.
        case sink

        /// All nodes are placed on the minimum rank, and the only nodes on the
        /// minimum rank belong to some subgraph with `rank="source"` or `rank="min"`.
        case max
    }

    private struct Node: Comparable {
        let id: NodeId
        var attributes: Attributes = Attributes()

        var label: String {
            get {
                attributes["label"]?.rawValue ?? ""
            }
            set {
                attributes["label"] = .string(newValue)
            }
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.label < rhs.label
        }
    }

    private struct Connection: Comparable {
        var idFrom: NodeId
        var idTo: NodeId
        var attributes: Attributes = Attributes()

        var label: String? {
            get {
                attributes["label"]?.rawValue
            }
            set {
                if let label = newValue {
                    attributes["label"] = .string(label)
                } else {
                    attributes.removeValue(forKey: "label")
                }
            }
        }

        var color: String? {
            get {
                attributes["color"]?.rawValue
            }
            set {
                if let label = newValue {
                    attributes["color"] = .string(label)
                } else {
                    attributes.removeValue(forKey: "color")
                }
            }
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            guard lhs.idTo == rhs.idTo else {
                return lhs.idTo < rhs.idTo
            }
            guard lhs.idFrom == rhs.idFrom else {
                return lhs.idFrom < rhs.idFrom
            }

            switch (lhs.label, rhs.label) {
            case (nil, nil):
                return false
            case (let a?, let b?):
                return a < b
            case (_?, _):
                return true
            case (_, _?):
                return false
            }
        }
    }

    /// A group of node definitions.
    private class Group {
        /// The kind of this group.
        var kind: Kind

        /// List of subgroups within this group.
        var subgroups: [Group] = []

        /// List of nodes contained within this group.
        var nodes: [Node] = []

        /// List of connections contained within this group.
        var connections: [Connection] = []

        var isSingleGroup: Bool {
            subgroups.count == 1 && nodes.isEmpty && connections.isEmpty
        }
        var isSingleNode: Bool {
            subgroups.isEmpty && nodes.count == 1 && connections.isEmpty
        }

        /// Attributes of this group.
        var attributes: Attributes = [:]

        /// The string title for this group.
        var title: String? {
            get {
                attributes["label"]?.rawValue
            }
            set {
                attributes["label"] = newValue.map(AttributeValue.string)
            }
        }

        /// Used during group merging- returns a copy of the attributes dictionary
        /// with the title label attribute removed.
        var attributesExceptTitle: Attributes {
            var copy = attributes
            copy["label"] = nil
            return copy
        }

        weak var supergroup: Group?

        init(title: String?, kind: Kind) {
            self.kind = kind

            self.title = title
        }

        /// Recursively simplifies this group's hierarchy, returning the root of
        /// the new simplified hierarchy.
        ///
        /// Groups that have different attributes, except for their title, are
        /// not merged.
        func simplify() -> Group {
            if isSingleGroup {
                let group = subgroups[0].simplify()
                guard group.attributesExceptTitle == attributesExceptTitle else {
                    return self
                }

                switch (title, group.title) {
                case (let t1?, let t2?):
                    group.title = "\(t1)/\(t2)"
                case (let t1?, nil):
                    group.title = t1
                default:
                    break
                }

                return group
            }

            let group = Group(title: title, kind: kind)
            group.attributes = attributes
            group.nodes = nodes
            group.connections = connections

            for subgroup in subgroups {
                let newSubgroup = subgroup.simplify()

                guard subgroup.attributesExceptTitle == attributesExceptTitle else {
                    group.addSubgroup(newSubgroup)
                    continue
                }

                if newSubgroup.isSingleNode {
                    group.nodes.append(newSubgroup.nodes[0])
                } else {
                    group.addSubgroup(newSubgroup)
                }
            }

            return group
        }

        func generateGraph(
            in out: StringOutput,
            options: Options,
            spacer: SpacerToken? = nil,
            clusterCounter: inout Int
        ) {

            // If this group contains only a single subgroup, forward printing
            // to that group transparently, instead.
            if options.simplifyGroups && isSingleGroup {
                subgroups[0].generateGraph(
                    in: out,
                    options: options,
                    spacer: spacer,
                    clusterCounter: &clusterCounter
                )

                return
            }

            let spacer = spacer ?? out.spacerToken()

            // Apply attributes
            if !attributes.isEmpty {
                spacer.apply()
                out(line: attributes.toInlineDotFileString())
                spacer.reset()
            }

            if !nodes.isEmpty {
                spacer.apply()

                for node in nodes {
                    let properties = node.attributes.toDotFileString()
                    let nodeString = dotFileNodeId(for: node.id)

                    if !properties.isEmpty {
                        out(line: nodeString + " \(properties)")
                    } else {
                        out(line: nodeString)
                    }
                }

                spacer.reset()
            }

            if !subgroups.isEmpty {
                // Populate subgroups
                for group in subgroups {
                    spacer.apply()

                    let lead: String
                    switch group.kind {
                    case .anonymous, .root:
                        lead = ""
                    case .subgraph:
                        lead = "subgraph"
                    case .cluster:
                        clusterCounter += 1
                        lead = "subgraph cluster_\(clusterCounter)"
                    }

                    if lead != "" {
                        out(line: "\(lead) {")
                    } else {
                        out(line: "{")
                    }
                    out.indented {
                        group.generateGraph(
                            in: out,
                            options: options,
                            spacer: out.spacerToken(disabled: true),
                            clusterCounter: &clusterCounter
                        )
                    }
                    out(line: "}")

                    spacer.reset()
                }
            }

            if !connections.isEmpty {
                spacer.apply()

                for connection in connections.sorted() {
                    let conString =
                        "\(dotFileNodeId(for: connection.idFrom)) -> \(dotFileNodeId(for: connection.idTo))"

                    let properties = connection.attributes.toDotFileString()

                    if !properties.isEmpty {
                        out(line: conString + " \(properties)")
                    } else {
                        out(line: conString)
                    }
                }

                spacer.reset()
            }
        }

        /// Returns the textual ID to use when emitting a given node ID on .dot
        /// files.
        func dotFileNodeId(for nodeId: NodeId) -> String {
            "n\(nodeId.description)"
        }

        /// Returns all connections of a given node within this group's hierarchy.
        func allConnections(of nodeId: NodeId) -> [Connection] {
            var result: [Connection] = []

            visitConnections { connection, _ in
                if connection.idFrom == nodeId || connection.idTo == nodeId {
                    result.append(connection)
                }
                return true
            }

            return result
        }

        /// Returns all connections that participate in one or more of the given
        /// node IDs within this group's hierarchy.
        func allConnections(of nodeIds: some Sequence<NodeId>) -> [Connection] {
            let nodeIds = Set(nodeIds)
            var result: [Connection] = []

            visitConnections { connection, _ in
                if nodeIds.contains(connection.idFrom) || nodeIds.contains(connection.idTo) {
                    result.append(connection)
                }
                return true
            }

            return result
        }

        func findNode(id: NodeId) -> Node? {
            if let node = nodes.first(where: { $0.id == id }) {
                return node
            }

            for group in subgroups {
                if let node = group.findNode(id: id) {
                    return node
                }
            }

            return nil
        }

        func findNodeId(label: String) -> NodeId? {
            if let node = nodes.first(where: { $0.label == label }) {
                return node.id
            }

            for group in subgroups {
                if let id = group.findNodeId(label: label) {
                    return id
                }
            }

            return nil
        }

        func findConnection(from: NodeId, to: NodeId) -> Connection? {
            if let connection = connections.first(where: { $0.idFrom == from && $0.idTo == to }) {
                return connection
            }

            for group in subgroups {
                if let connection = group.findConnection(from: from, to: to) {
                    return connection
                }
            }

            return nil
        }

        /// Finds the group that contains a given node ID within this group
        /// hierarchy.
        func findGroupForNode(id: NodeId) -> Group? {
            if nodes.contains(where: { $0.id == id }) {
                return self
            }

            for group in subgroups {
                if let g = group.findGroupForNode(id: id) {
                    return g
                }
            }

            return nil
        }

        func getOrCreateGroup(_ path: [String]) -> Group {
            if path.isEmpty {
                return self
            }

            let next = path[0]
            let remaining = Array(path.dropFirst())

            for group in subgroups {
                if group.title == next {
                    return group.getOrCreateGroup(remaining)
                }
            }

            let group = Group(title: next, kind: .cluster)
            addSubgroup(group)
            return group.getOrCreateGroup(remaining)
        }

        func addSubgroup(_ group: Group) {
            group.supergroup = self
            subgroups.append(group)
        }

        func addNode(_ node: Node) {
            nodes.append(node)
        }

        func addNodes(_ nodes: some Sequence<Node>) {
            self.nodes.append(contentsOf: nodes)
        }

        /// Adds a given connection to the first common ancestor of the two nodes
        /// it references within this group's hierarchy.
        func addConnection(_ connection: Connection) {
            let target: Group

            let g1 = findGroupForNode(id: connection.idFrom)
            let g2 = findGroupForNode(id: connection.idTo)

            if
                let g1 = g1,
                let g2 = g2,
                let ancestor = Self.firstCommonAncestor(between: g1, g2)
            {
                target = ancestor
            } else {
                target = self
            }

            target.connections.append(connection)
        }

        /// Removes a given node ID from this group, or one of its subgroups, if
        /// they contain the node ID.
        ///
        /// Also removes any connections that reference the given node ID from
        /// this group's hierarchy.
        ///
        /// Returns the node object that belonged to the identifier, if it was
        /// found and removed.
        @discardableResult
        func removeNode(_ nodeId: NodeId, removeConnections: Bool = true) -> Node? {
            guard let group = findGroupForNode(id: nodeId) else {
                return nil
            }

            if let index = group.nodes.firstIndex(where: { $0.id == nodeId }) {
                defer {
                    group.nodes.remove(at: index)

                    if removeConnections {
                        self.removeConnections(for: nodeId)
                    }
                }

                return group.nodes[index]
            }

            return nil
        }

        /// Removes a given sequence of node IDs from this group, or one of its
        /// subgroups, if they contain the node IDs.
        ///
        /// Also removes any connections that reference the node IDs from this
        /// group's hierarchy.
        ///
        /// Returns an array of node objects that belonged to the identifiers,
        /// whenever they successfully bound to an existing node.
        func removeNodes(_ nodeIds: some Sequence<NodeId>, removeConnections: Bool = true) -> [Node] {
            nodeIds.compactMap { nodeId in
                self.removeNode(nodeId, removeConnections: removeConnections)
            }
        }

        /// Recursively removes connections referencing a given node ID from this
        /// group hierarchy.
        ///
        /// Returns the array of connections that where removed.
        @discardableResult
        func removeConnections(for nodeId: NodeId) -> [Connection] {
            var result: [Connection] = []
            visit { group in
                for (i, connection) in group.connections.enumerated().reversed() {
                    if connection.idFrom == nodeId || connection.idTo == nodeId {
                        result.append(connection)
                        group.connections.remove(at: i)
                    }
                }
                return true
            }

            return result
        }

        /// Moves all given node IDs into the first common ancestor between them
        /// within this group.
        ///
        /// If this group does not contain all the node IDs, no change is made.
        ///
        /// Connections between nodes are also moved to the common ancestor.
        func moveNodesToCommonAncestor(_ nodeIds: some Sequence<NodeId>) {
            var groups: [Group] = []
            for nodeId in nodeIds {
                guard let owner = findGroupForNode(id: nodeId) else {
                    return
                }

                groups.append(owner)
            }

            let ancestor = Self.firstCommonAncestor(of: groups) ?? self
            let connections = allConnections(of: nodeIds)

            for nodeId in nodeIds {
                guard let node = removeNode(nodeId) else {
                    continue
                }

                ancestor.addNode(node)
            }
            for connection in connections {
                addConnection(connection)
            }
        }

        /// Opens a mutation closure for modifying the properties of a node with
        /// a specified ID within this group or one of its subgroups.
        ///
        /// Returns `true` if the node ID was found and the closure invoked,
        /// otherwise returns `false`.
        func withNodeId(_ nodeId: NodeId, _ closure: (inout Node) -> Void) -> Bool {
            if let index = nodes.firstIndex(where: { $0.id == nodeId }) {
                closure(&nodes[index])
                return true
            }

            for group in subgroups {
                if group.withNodeId(nodeId, closure) {
                    return true
                }
            }

            return false
        }

        /// Visits all groups within this group hierarchy with a given closure,
        /// ending the visit the first time it returns `false` or when all
        /// groups have been visited.
        func visit(_ visitor: (Group) -> Bool) {
            var queue = [self]

            while !queue.isEmpty {
                let next = queue.removeFirst()
                if !visitor(next) {
                    return
                }

                for group in next.subgroups {
                    queue.append(group)
                }
            }
        }

        /// Visits all nodes within this group hierarchy with a given closure,
        /// ending the visit the first time it returns `false` or when all
        /// nodes have been visited.
        func visitNodes(_ visitor: (Node) -> Bool) {
            var queue = [self]

            while !queue.isEmpty {
                let next = queue.removeFirst()
                for node in next.nodes {
                    if !visitor(node) {
                        return
                    }
                }

                for group in next.subgroups {
                    queue.append(group)
                }
            }
        }

        /// Visits all connections within this group hierarchy with a given closure,
        /// ending the visit the first time it returns `false` or when all
        /// connections have been visited.
        func visitConnections(_ visitor: (Connection, Group) -> Bool) {
            var queue = [self]

            while !queue.isEmpty {
                let next = queue.removeFirst()
                for connection in next.connections {
                    if !visitor(connection, next) {
                        return
                    }
                }

                for group in next.subgroups {
                    queue.append(group)
                }
            }
        }

        func isDescendant(of view: Group) -> Bool {
            var parent: Group? = self
            while let p = parent {
                if p === view {
                    return true
                }
                parent = p.supergroup
            }

            return false
        }

        static func firstCommonAncestor(of groups: [Group]) -> Group? {
            guard var common = groups.first else { return nil }

            for group in groups.dropFirst() {
                guard let ancestor = firstCommonAncestor(between: group, common) else {
                    return nil
                }

                common = ancestor
            }

            return common
        }

        static func firstCommonAncestor(
            between group1: Group,
            _ group2: Group
        ) -> Group? {

            if group1 === group2 {
                return group1
            }

            var parent: Group? = group1
            while let p = parent {
                if group2.isDescendant(of: p) {
                    return p
                }

                parent = p.supergroup
            }

            return nil
        }

        /// The semantic kind of a group.
        enum Kind {
            /// The root of a graphviz file.
            ///
            /// There can only ever be one root group in a graphviz file, and it
            /// must be the common ancestor of all other groups.
            case root

            /// A standard subgraph.
            case subgraph

            /// A cluster group, or a subgraph with a root graph.
            case cluster

            /// A group that is emitted without a leading keyword.
            case anonymous
        }
    }

    /// Options for graph generation
    public struct Options {
        /// Default generation options
        public static let `default`: Self = Self()

        /// Whether to simplify groups before emitting the final graph file.
        /// Simplification collapses subgraphs that only contain subgraphs with
        /// no nodes/connections.
        public var simplifyGroups: Bool

        public init(
            simplifyGroups: Bool = true
        ) {
            self.simplifyGroups = simplifyGroups
        }
    }

    fileprivate class SpacerToken {
        var out: StringOutput
        var didApply: Bool

        init(out: StringOutput, didApply: Bool = false) {
            self.out = out
            self.didApply = didApply
        }

        /// If this spacer token is reset, applies a blank line to the buffer.
        ///
        /// Must be reset with ``reset()`` before it can applied again.
        func apply() {
            guard !didApply else { return }
            didApply = true

            out()
        }

        /// Resets this spacer token so it can be applied again.
        func reset() {
            didApply = false
        }
    }
}

/// Outputs to a string buffer
private final class StringOutput {
    var indentDepth: Int = 0
    var ignoreCallChange = false
    private(set) public var buffer: String = ""

    init() {

    }

    /// Creates a spacer token that issues empty lines as spacing between elements
    /// in generated graphviz files.
    func spacerToken(disabled: Bool = false) -> GraphViz.SpacerToken {
        .init(out: self, didApply: disabled)
    }

    func callAsFunction() {
        output(line: "")
    }

    func callAsFunction(line: String) {
        output(line: line)
    }

    func callAsFunction(lineAndIndent line: String, _ block: () -> Void) {
        output(line: line)
        indented(perform: block)
    }

    func callAsFunction(beginBlock line: String, _ block: () -> Void) {
        output(line: "\(line) {")
        indented(perform: block)
        output(line: "}")
    }

    func outputRaw(_ text: String) {
        buffer += text
    }

    func output(line: String) {
        if !line.isEmpty {
            outputIndentation()
            buffer += line
        }

        outputLineFeed()
    }

    func outputIndentation() {
        buffer += indentString()
    }

    func outputLineFeed() {
        buffer += "\n"
    }

    func outputInline(_ content: String) {
        buffer += content
    }

    func increaseIndentation() {
        indentDepth += 1
    }

    func decreaseIndentation() {
        guard indentDepth > 0 else { return }

        indentDepth -= 1
    }

    func outputInlineWithSpace(_ content: String) {
        outputInline(content)
        outputInline(" ")
    }

    func indented(perform block: () -> Void) {
        increaseIndentation()
        block()
        decreaseIndentation()
    }

    private func indentString() -> String {
        return String(repeating: " ", count: 4 * indentDepth)
    }
}

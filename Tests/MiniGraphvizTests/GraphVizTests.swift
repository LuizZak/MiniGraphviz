import XCTest

@testable import MiniGraphviz

class GraphVizTests: XCTestCase {
    func testGenerateFile_emptyGraph_nilRootGraphName() {
        let sut = makeSut()

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]
        }
        """)
        .diff(sut.generateFile())
    }

    func testGenerateFile_emptyGraph_nonNilRootGraphName() {
        let sut = makeSut(rootGraphName: "testGraph")

        diffTest(expected: """
        digraph testGraph {
            graph [rankdir=LR]
        }
        """)
        .diff(sut.generateFile())
    }

    func testGenerateFile_rankDir() {
        let sut = makeSut(rootGraphName: "testGraph")
        sut.rankDir = .bottomToTop

        diffTest(expected: """
        digraph testGraph {
            graph [rankdir=BT]
        }
        """)
        .diff(sut.generateFile())
    }

    func testGenerateFile_rankDir_doesNotEmitIfRankDirIsTopToBottom() {
        let sut = makeSut(rootGraphName: "testGraph")
        sut.rankDir = .topToBottom

        diffTest(expected: """
        digraph testGraph {
        }
        """)
        .diff(sut.generateFile())
    }

    func testGenerateFile_singleNode() {
        let sut = makeSut()
        sut.createNode(label: "node")

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            n1 [label="node"]
        }
        """)
        .diff(sut.generateFile())
    }

    func testGenerateFile_singleConnection() {
        let sut = makeSut()
        let n1 = sut.createNode(label: "node1")
        let n2 = sut.createNode(label: "node2")
        sut.addConnection(from: n1, to: n2)

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            n1 [label="node1"]
            n2 [label="node2"]

            n1 -> n2
        }
        """)
        .diff(sut.generateFile())
    }

    func testGenerateFile_singleConnection_withLabel() {
        let sut = makeSut()
        let n1 = sut.createNode(label: "node1")
        let n2 = sut.createNode(label: "node2")
        sut.addConnection(from: n1, to: n2, label: "connection label")

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            n1 [label="node1"]
            n2 [label="node2"]

            n1 -> n2 [label="connection label"]
        }
        """)
        .diff(sut.generateFile())
    }

    func testGenerateFile_singleConnection_withColor() {
        let sut = makeSut()
        let n1 = sut.createNode(label: "node1")
        let n2 = sut.createNode(label: "node2")
        sut.addConnection(from: n1, to: n2, color: "red")

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            n1 [label="node1"]
            n2 [label="node2"]

            n1 -> n2 [color="red"]
        }
        """)
        .diff(sut.generateFile())
    }

    func testGenerateFile_singleConnection_withLabel_withColor() {
        let sut = makeSut()
        let n1 = sut.createNode(label: "node1")
        let n2 = sut.createNode(label: "node2")
        sut.addConnection(from: n1, to: n2, label: "connection label", color: "red")

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            n1 [label="node1"]
            n2 [label="node2"]

            n1 -> n2 [color="red", label="connection label"]
        }
        """)
        .diff(sut.generateFile())
    }

    func testGenerateFile_twoGroups_withNodeConnections() {
        let sut = makeSut()
        sut.createNode(label: "node1", groups: ["Subgroup"])
        sut.createNode(label: "node2", groups: ["Subgroup", "Inner Subgroup"])
        sut.createNode(label: "node3", groups: ["Subgroup", "Inner Subgroup"])
        sut.addConnection(fromLabel: "node2", toLabel: "node3")

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            label = "Subgroup"

            n1 [label="node1"]

            subgraph cluster_1 {
                label = "Inner Subgroup"

                n2 [label="node2"]
                n3 [label="node3"]

                n2 -> n3
            }
        }
        """)
        .diff(sut.generateFile())
    }

    func testCreateNodeWithLabel_duplicatesNodes() {
        let sut = makeSut()
        let n1 = sut.createNode(label: "node")
        let n2 = sut.createNode(label: "node")

        XCTAssertNotEqual(n1, n2)
        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            n1 [label="node"]
            n2 [label="node"]
        }
        """)
        .diff(sut.generateFile())
    }

    func testGetOrCreateLabel_doesNotDuplicateNodes() {
        let sut = makeSut()
        let n1 = sut.getOrCreate(label: "node")
        let n2 = sut.getOrCreate(label: "node")

        XCTAssertEqual(n1, n2)
        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            n1 [label="node"]
        }
        """)
        .diff(sut.generateFile())
    }

    func testCreateNodeWithLabel_withSingleGroup() {
        let sut = makeSut()
        sut.createNode(label: "node", groups: ["Subgroup"])

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            label = "Subgroup"

            n1 [label="node"]
        }
        """)
        .diff(sut.generateFile())
    }

    func testCreateNodeWithLabel_withAttributes() {
        let sut = makeSut()
        let n1 = sut.createNode(
            label: "node",
            attributes: ["attr": .double(1.0)]
        )
        let n2 = sut.createNode(
            label: "node",
            attributes: ["zAttr": .string("a value")]
        )

        XCTAssertNotEqual(n1, n2)
        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            n1 [attr=1.0, label="node"]
            n2 [label="node", zAttr="a value"]
        }
        """)
        .diff(sut.generateFile())
    }

    func testCreateNodeWithLabel_withSingleGroup_simplifyGroups_false() {
        let sut = makeSut()
        sut.createNode(label: "node", groups: ["Subgroup"])

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            subgraph cluster_1 {
                label = "Subgroup"

                n1 [label="node"]
            }
        }
        """)
        .diff(sut.generateFile(
            options: .init(
                simplifyGroups: false
            )
        ))
    }

    func testCreateNodeWithLabel_twoGroups() {
        let sut = makeSut()
        sut.createNode(label: "node1", groups: ["Subgroup"])
        sut.createNode(label: "node2", groups: ["Subgroup", "Inner Subgroup"])
        sut.createNode(label: "node3", groups: ["Subgroup", "Inner Subgroup"])

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            label = "Subgroup"

            n1 [label="node1"]

            subgraph cluster_1 {
                label = "Inner Subgroup"

                n2 [label="node2"]
                n3 [label="node3"]
            }
        }
        """)
        .diff(sut.generateFile())
    }

    func testAddConnection_attributes() {
        let sut = makeSut()
        let n1 = sut.createNode(label: "node1")
        let n2 = sut.createNode(label: "node2")

        sut.addConnection(
            from: n1,
            to: n2,
            attributes: [
                "label": .string("connection label"),
                "color": .string("red"),
                "penwidth": 0.5,
            ]
        )

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            n1 [label="node1"]
            n2 [label="node2"]

            n1 -> n2 [color="red", label="connection label", penwidth=0.5]
        }
        """)
        .diff(sut.generateFile())
    }

    func testSetAttributesForNodeId() {
        let sut = makeSut()
        let node = sut.createNode(label: "node")

        sut.setAttributes(forNodeId: node, ["attr": .double(1.0)])

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            n1 [attr=1.0, label="node"]
        }
        """)
        .diff(sut.generateFile())
    }

    func testSetAttributesForNodeId_unknownNodeId_doesNothing() {
        let sut = makeSut()
        let unknownId = makeSut().createNode(label: "node")

        sut.setAttributes(forNodeId: unknownId, ["attr": .double(1.0)])

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]
        }
        """)
        .diff(sut.generateFile())
    }

    func testGroupAsRank() {
        let sut = makeSut()
        let node1 = sut.createNode(label: "n1")
        sut.createNode(label: "n2")
        let node3 = sut.createNode(label: "n3")
        let node4 = sut.createNode(label: "n4")
        sut.addConnection(fromLabel: "n1", toLabel: "n2")
        sut.addConnection(fromLabel: "n2", toLabel: "n4")
        sut.addConnection(fromLabel: "n4", toLabel: "n3")
        sut.addConnection(fromLabel: "n3", toLabel: "n1")

        sut.groupAsRank([node1, node3], rank: .min)
        sut.groupAsRank([node4], rank: .sink)

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            n2 [label="n2"]

            {
                rank = "min"

                n1 [label="n1"]
                n3 [label="n3"]
            }

            {
                rank = "sink"

                n4 [label="n4"]
            }

            n3 -> n1
            n1 -> n2
            n4 -> n3
            n2 -> n4
        }
        """)
        .diff(sut.generateFile())
    }

    func testGroupAsRank_nodesInGroups() {
        let sut = makeSut()
        let node1 = sut.createNode(label: "n1", groups: ["g1", "g2"])
        sut.createNode(label: "n2", groups: ["g3"])
        let node3 = sut.createNode(label: "n3", groups: ["g1"])
        let node4 = sut.createNode(label: "n4")
        sut.addConnection(fromLabel: "n1", toLabel: "n2")
        sut.addConnection(fromLabel: "n2", toLabel: "n4")
        sut.addConnection(fromLabel: "n4", toLabel: "n3")
        sut.addConnection(fromLabel: "n3", toLabel: "n1")

        sut.groupAsRank([node1, node3], rank: .min)
        sut.groupAsRank([node4], rank: .sink)

        diffTest(expected: """
        digraph {
            graph [rankdir=LR]

            n2 [label="n2"]

            subgraph cluster_1 {
                label = "g1"

                subgraph cluster_2 {
                    label = "g2"
                }

                {
                    rank = "min"

                    n1 [label="n1"]
                    n3 [label="n3"]
                }

                n3 -> n1
            }

            {
                rank = "sink"

                n4 [label="n4"]
            }

            n1 -> n2
            n4 -> n3
            n2 -> n4
        }
        """)
        .diff(sut.generateFile())
    }
}

// MARK: - Test internals

private func makeSut(rootGraphName: String? = nil) -> GraphViz {
    GraphViz(rootGraphName: rootGraphName)
}

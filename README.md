# MiniGraphviz

A teeny-tiny-weeny Graphviz-emitting library written in Swift available as a Swift Package. 

Mostly used as a dependency by my other OSS projects.

Sample usage:

```swift
let viz = Graphviz()

viz.createNode(label: "node1", groups: ["Subgroup"])
viz.createNode(label: "node2", groups: ["Subgroup", "Inner Subgroup"])
viz.createNode(label: "node3", groups: ["Subgroup", "Inner Subgroup"])
viz.addConnection(
    fromLabel: "node2",
    toLabel: "node3",
    attributes: [
        "label": .string("connection label"),
        "color": .string("red"),
        "penwidth": 0.5,
    ]
)

print(viz.generateFile())
```

prints:

```viz
digraph {
    graph [rankdir=LR]

    label = "Subgroup"

    n1 [label="node1"]

    subgraph cluster_1 {
        label = "Inner Subgroup"

        n2 [label="node2"]
        n3 [label="node3"]

        n2 -> n3 [color="red", label="connection label", penwidth=0.5]
    }
}
```

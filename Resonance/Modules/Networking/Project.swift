import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.featureFramework(
    name: "Networking",
    dependencies: [
        .project(target: "Core", path: .relativeToRoot("Modules/Core")),
    ]
)

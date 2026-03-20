import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.featureFramework(
    name: "Features",
    dependencies: [
        .project(target: "UIComponents", path: .relativeToRoot("Modules/UIComponents")),
        .project(target: "Core", path: .relativeToRoot("Modules/Core")),
        .project(target: "Networking", path: .relativeToRoot("Modules/Networking")),
    ]
)

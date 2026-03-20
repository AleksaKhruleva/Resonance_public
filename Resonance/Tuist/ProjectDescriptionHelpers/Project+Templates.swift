import ProjectDescription

extension Project {
    public static func featureFramework(
        name: String,
        haveResources: Bool = false,
        infoPlist: InfoPlist = .default,
        dependencies: [TargetDependency] = []
    ) -> Project {
        let sourcesBF = BuildableFolder(stringLiteral: "Sources")
        let resourcesBF = BuildableFolder(stringLiteral: "Resources")
        
        let buildableFolders = haveResources ? [sourcesBF, resourcesBF] : [sourcesBF]
        
        return Project(
            name: name,
            settings: .settings(defaultSettings: .recommended),
            targets: [
                .target(
                    name: name,
                    destinations: .iOS,
                    product: .framework,
                    bundleId: "site.aleksa.Resonance.\(name)",
                    deploymentTargets: .iOS("26.1"),
                    infoPlist: infoPlist,
                    buildableFolders: buildableFolders,
                    dependencies: dependencies
                )
            ]
        )
    }
}

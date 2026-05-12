import ArgumentParser

@main
struct ShowcaseCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "showcase",
        abstract: "Generate narrative developer portfolios from project artifacts.",
        subcommands: [
            GatherCommand.self,
            NarrateCommand.self,
            RenderCommand.self,
            RefreshCommand.self,
            PortfolioCommand.self,
            InfographicsCommand.self,
        ]
    )
}

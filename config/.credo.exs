%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: []
      },
      checks: %{
        enabled: [
          # For others you can also set parameters
          {Credo.Check.Readability.MaxLineLength, priority: :low, max_length: 120},
          {Credo.Check.Design.TagTODO, exit_status: 0}
        ],
        disabled: [
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []}
        ]
      }
    }
  ]
}

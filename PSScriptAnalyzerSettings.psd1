@{
    Severity = @('Error', 'Warning', 'Information')
    IncludeRules = @('*')
    ExcludeRules = @(
        # These scripts are one-shot Windows setup, not PowerShell modules.
        'PSUseShouldProcessForStateChangingFunctions'
        'PSUseSingularNouns'
    )
}

if !Object.const_defined?(:WORKFLOW_VERSION)
    load('VERSION')
    pre_release_append = ((PRE_RELEASE_IDENTIFIER ||= "") != "") ? "-"+PRE_RELEASE_IDENTIFIER : ""
    WORKFLOW_VERSION="#{MAJOR}.#{MINOR}.#{PATCH}#{pre_release_append}"

    # Due to a source-breaking change, this currently differs from the standard
    # `WORKFLOW_VERSION` used for the other libraries.
    WORKFLOW_CONCURRENCY_VERSION="#{CONCURRENCY_MAJOR}.#{CONCURRENCY_MINOR}.#{CONCURRENCY_PATCH}"

    if (WORKFLOW_CONCURRENCY_VERSION <=> WORKFLOW_VERSION) != 1
        puts "[note]: WORKFLOW_CONCURRENCY_VERSION (value: #{WORKFLOW_CONCURRENCY_VERSION}) is not greater than WORKFLOW_VERSION (value: #{WORKFLOW_VERSION}). Please remove WORKFLOW_CONCURRENCY_VERSION in favor of WORKFLOW_VERSION if differing versions are no longer required."
    end
end

load('VERSION')

pre_release_append = ((PRE_RELEASE_IDENTIFIER ||= "") != "") ? "-"+PRE_RELEASE_IDENTIFIER : ""

WORKFLOW_VERSION="#{MAJOR}.#{MINOR}.#{PATCH}#{pre_release_append}"

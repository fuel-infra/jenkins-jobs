def G_URL = build.buildVariableResolver.resolve('GERRIT_CHANGE_URL')
cancel = (G_URL) ? true : false

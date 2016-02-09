def G_STATUS = build.buildVariableResolver.resolve('GERRIT_CHANGE_STATUS')
cancel = (G_STATUS ==  "MERGED" ) ? false : true

import com.sonyericsson.hudson.plugins.gerrit.trigger.config.PluginConfig
import com.sonyericsson.hudson.plugins.gerrit.trigger.GerritServer
import com.sonyericsson.hudson.plugins.gerrit.trigger.PluginImpl

import net.sf.json.JSONObject

class GerritTriggerConfigInvalidServer extends Exception{}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// usage example with ssh private key authentication (note that key file must be already present on Master)
// $ /usr/bin/wget -q http://localhost:8080/jnlpJars/jenkins-cli.jar -O jenkins-cli.jar
// $ java -jar jenkins-cli.jar -i path_to_ssh_private_key -s http://localhost:8080 groovy gerritsetup.groovy gerrit_trigger_addsrv gerrit_server1 gerrit.fuel-infra.org http://gerrit.fuel-infra.org '' '' uname-server1 '' '/path/to/keyfile/' '' '' '' '' '' '' ''
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class Actions {
  Actions(out) { this.out = out }
  def out

  ///////////////////////////////////////////////////////////////////////////////
  // this -> is gerrit_global_cfg
  ///////////////////////////////////////////////////////////////////////////////
  //
  // Configures Gerrit global settings
  //
  void gerrit_global_cfg(String recievingWorkersThreads=null, String sendingWorkersThreads=null)
  {
    def gerritPlugin = PluginImpl.getInstance()
    if(recievingWorkersThreads.isNumber()) {
      gerritPlugin.getPluginConfig().setNumberOfReceivingWorkerThreads(recievingWorkersThreads.toInteger())
    }
    if(sendingWorkersThreads.isNumber()){
      gerritPlugin.getPluginConfig().setNumberOfSendingWorkerThreads(sendingWorkersThreads.toInteger())
    }
  }

  ///////////////////////////////////////////////////////////////////////////////
  // this -> is gerrit_trigger_addsrv
  ///////////////////////////////////////////////////////////////////////////////
  //
  // Adds a new server to gerrit trigger config & configures it
  //
  void gerrit_trigger_addsrv(
      String gerritServerName,
      String gerritHostName=null,
      String gerritFrontEndUrl=null,
      String gerritSShPort=29418,
      String gerritProxy=null,
      String gerritUserName=null,
      String gerritAuthKeyFile=null,
      String gerritAuthKeyFilePassword=null,
      String gerritBuildCurrentPatchesOnly=false,
      String gerritVerifiedCmdBuildStarted=null,
      String gerritVerifiedCmdBuildSuccessful=null,
      String gerritVerifiedCmdBuildFailed=null,
      String gerritVerifiedCmdBuildUnstable=null,
      String gerritVerifiedCmdBuildNotBuilt=null
    )
  {
    def plugin = PluginImpl.getInstance()
    if(plugin.containsServer(gerritServerName) || GerritServer.ANY_SERVER.equals(gerritServerName) || gerritServerName == "" || gerritServerName == null) {
      throw new GerritTriggerConfigInvalidServer()
    }
    def srv = new GerritServer(gerritServerName)
    plugin.addServer(srv)
    plugin.save()
    // configure new server now. use json to do that.
    JSONObject srv_list_cfg = new JSONObject()
    def srv_cfg = srv.getConfig()

    if (gerritHostName != "" && gerritHostName != null) {
      srv_list_cfg.put("gerritHostName", gerritHostName)
    }

    if(gerritFrontEndUrl != "" && gerritFrontEndUrl != null) {
      srv_list_cfg.put("gerritFrontEndUrl", gerritFrontEndUrl)
    }

    if(gerritSShPort != "" && gerritSShPort != null) {
      srv_list_cfg.put("gerritSShPort", gerritSShPort)
    }

    if(gerritProxy != "" && gerritProxy != null) {
      srv_list_cfg.put("gerritProxy", gerritProxy)
    }

    if(gerritUserName != "" && gerritUserName != null) {
      srv_list_cfg.put("gerritUserName", gerritUserName)
    }

    if(gerritAuthKeyFile != "" && gerritAuthKeyFile != null) {
      srv_list_cfg.put("gerritAuthKeyFile", gerritAuthKeyFile )
    }

    if(gerritAuthKeyFilePassword != "" && gerritAuthKeyFilePassword != null) {
      srv_list_cfg.put("gerritAuthKeyFilePassword", gerritAuthKeyFilePassword)
    }

    if(gerritBuildCurrentPatchesOnly != "" && gerritBuildCurrentPatchesOnly != null) {
      srv_list_cfg.put("gerritBuildCurrentPatchesOnly", gerritBuildCurrentPatchesOnly.toBoolean())
    }

    if(gerritVerifiedCmdBuildStarted == "silent") {
      srv_list_cfg.put("gerritVerifiedCmdBuildStarted", "")
    } else if(gerritVerifiedCmdBuildStarted != null && gerritVerifiedCmdBuildStarted != "") {
      srv_list_cfg.put("gerritVerifiedCmdBuildStarted", gerritVerifiedCmdBuildStarted)
    }

    if(gerritVerifiedCmdBuildSuccessful == "silent") {
      srv_list_cfg.put("gerritVerifiedCmdBuildSuccessful", "")
    } else if(gerritVerifiedCmdBuildSuccessful != null && gerritVerifiedCmdBuildSuccessful != "") {
      srv_list_cfg.put("gerritVerifiedCmdBuildSuccessful", gerritVerifiedCmdBuildSuccessful)
    }

    if(gerritVerifiedCmdBuildFailed == "silent") {
      srv_list_cfg.put("gerritVerifiedCmdBuildFailed", "")
    } else if(gerritVerifiedCmdBuildFailed != null && gerritVerifiedCmdBuildFailed != "") {
      srv_list_cfg.put("gerritVerifiedCmdBuildFailed", gerritVerifiedCmdBuildFailed)
    }

    if(gerritVerifiedCmdBuildUnstable == "silent") {
      srv_list_cfg.put("gerritVerifiedCmdBuildUnstable", "")
    } else if(gerritVerifiedCmdBuildUnstable != null && gerritVerifiedCmdBuildUnstable != "") {
      srv_list_cfg.put("gerritVerifiedCmdBuildUnstable", gerritVerifiedCmdBuildUnstable)
    }

    if(gerritVerifiedCmdBuildNotBuilt == "silent") {
      srv_list_cfg.put("gerritVerifiedCmdBuildNotBuilt", "")
    } else if(gerritVerifiedCmdBuildNotBuilt != null && gerritVerifiedCmdBuildNotBuilt != "") {
      srv_list_cfg.put("gerritVerifiedCmdBuildNotBuilt", gerritVerifiedCmdBuildNotBuilt)
    }

    srv_cfg.setValues(srv_list_cfg)
    srv.setConfig(srv_cfg)
    srv.start()
    plugin.save()
  }
}

///////////////////////////////////////////////////////////////////////////////
// CLI Argument Processing
///////////////////////////////////////////////////////////////////////////////

actions = new Actions(out)
action = args[0]
if (args.length < 2) {
  actions."$action"()
} else {
    actions."$action"(*args[1..-1])
}

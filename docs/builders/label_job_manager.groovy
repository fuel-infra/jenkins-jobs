/////////////////////////////////////////////////////////////////
//
// Script to be used with Jenkins job for adding/removing
// labels from specified, or randomly selected, Jenkins node(s).
//
/////////////////////////////////////////////////////////////////

class WrongOrNotAllParametersPassed extends Exception{}
class CouldNotFindAllRequiredNodes extends Exception{}

// get current thread / Executor
def thr = Thread.currentThread()
def currentBuild = Thread.currentThread().executable
// get current build
def build = thr?.executable
def resolver = build.buildVariableResolver
def workspace = currentBuild.workspace.toString()
// locals
def label_value = resolver.resolve("LABEL_NAME")
def action = resolver.resolve("ACTION")
def rand_value = resolver.resolve("RANDOM_NODES")
def node_value = resolver.resolve("NODE")
// save artifacts in a file
def file_node = new File(workspace + '/file_node.txt')
def file_action = new File(workspace + '/file_action.txt')
def file_label = new File(workspace + '/file_label.txt')
// prevent executing jobs node from overkill
tries = 200
// globals
selected_nodes = []
random_probe_edge = 15
labels_list = []
nodes_blacklist = []

boolean remove_label(String labels=null)
{
  if(selected_nodes.size() < 1 || labels == null || labels == "") {
    throw new WrongOrNotAllParametersPassed()
  }
  labels_list = labels.split(' ')
  def repl = ''
  def old_label = ''
  def pattern = ''
  def label_fail_counter = 0

  for(String node : selected_nodes) {
    slave = hudson.model.Hudson.instance.slaves.find {
      slave -> slave.nodeName.equals(node)
    }
    // --- start of strict remove check ---
    // if all passed labels could not be matched = return false.
    for (String label : labels_list) {
      pattern = /.*\b$label\b.*/
      _old_label = slave.getLabelString()
      if(!_old_label.matches(pattern)) {
        label_fail_counter += 1
      }
    }
    // all labels failed to match?
    if(labels_list.size() == label_fail_counter) {
      // blacklist that node also.
      nodes_blacklist.add(node)
      return false
    }
    // --- end of strict remove check ---
    for (String label : labels_list) {
      label = slave.labelString.replaceAll(/(^|\W)($label)($|\W)/, "\$1$repl\$3")
      slave.setLabelString(label)
    }
  }
  return true
}

void add_label(String node_name=null, String labels=null)
{
  if(selected_nodes.size() < 1 || labels == null || labels == "") {
    throw new WrongOrNotAllParametersPassed()
  }
  labels_list = labels.split(' ')
  def _label = ''
  def _old_label = ''
  def pattern = ''

  for(String node : selected_nodes) {
    slave = hudson.model.Hudson.instance.slaves.find {
      slave -> slave.nodeName.equals(node)
    }
    for(String label : labels_list) {
      pattern = /.*\b$label\b.*/
      _old_label = slave.getLabelString()
      if(!_old_label.matches(pattern)) {
        _label = slave.getLabelString() + " " + label
        slave.setLabelString(_label)
      }
    }
  }
}

void choose_nodes(int nodes)
{
  def pick_nodes = true
  def pattern = ''
  def _slave = ''
  def b_list = false
  def iter = 0
  def node = false
  int random = 0

  while(pick_nodes) {
    tries -= 1
    for (slave in hudson.model.Hudson.instance.slaves) {
      if (tries < 1) {
        throw new CouldNotFindAllRequiredNodes()
      }
      if(selected_nodes.size() < nodes) {
        _slave = slave.name
        pattern = /.*\b$_slave\b.*/
        if(!slave.getComputer().isOffline())
        {
          // was that node already selected?
          node = selected_nodes.any { it =~ pattern }
          // also check if node is NOT blacklisted.
          b_list = nodes_blacklist.any { it == _slave }
          if(!b_list && !node) {
            if(iter == 0) {
            // within first iter get IDLE nodes only.
              if(slave.getComputer().countBusy() < 1) {
                selected_nodes.add(slave.name)
              }
            } else {
              // don't be so predictible when picking busy nodes.
              random = (int )(Math.random() * 100);
              if(random < random_probe_edge) {
                selected_nodes.add(slave.name)
              }
             }
          }
        }
      } else {
        pick_nodes = false
        break
      }
      iter += 1
    }
  }
}

void nodes(String rand_value=null, String node_value=null) {
  if(rand_value == "true") {
    if(node_value.isNumber()) {
        choose_nodes(node_value.toInteger())
      } else {
        throw new WrongOrNotAllParametersPassed()
      }
  } else {
    selected_nodes = node_value.split(' ')
  }
}
nodes(rand_value, node_value)

if(action == "ADD_LABEL") {
  add_label(node_value, label_value)
} else if (action == "REMOVE_LABEL") {
  while (true) {
    if(!remove_label(label_value)){
      // strict rm check returned false.
      // at this point a new node selection should happen
      // if nodes were selected randomly.
      if(rand_value == "true") {
        nodes(rand_value, node_value)
        if (tries < 1) {
          throw new CouldNotFindAllRequiredNodes()
        }
      }
    } else {
      break
    }
  }
} else {
  throw new WrongOrNotAllParametersPassed()
}

//  write artifacts
file_action.write 'ACTION=' + action
node_value = 'NODE='
for (String node : selected_nodes) {
  node_value += node + ' '
}
file_node.write node_value

label_value = 'LABEL='
for (String label : labels_list) {
  label_value += label + ' '
}
file_label.write label_value

// now prepare description
node_value = ''
for (String node : selected_nodes) {
  node_value += node + " <br />"
}
label_value = ''
for(String label : labels_list) {
  label_value += label + " <br />"
}

println("[Action]:<br />" + action + "<br />" + "[Labels]:<br />" + label_value + "[Nodes]:<br />" + node_value)
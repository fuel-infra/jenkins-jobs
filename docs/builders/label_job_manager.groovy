/////////////////////////////////////////////////////////////////
//
// Script to be used with Jenkins job for adding/removing
// labels from specified, or randomly selected, Jenkins node(s).
//
/////////////////////////////////////////////////////////////////

class NotAllParametersPassed extends Exception{}

// get current thread / Executor
def thr = Thread.currentThread()
def currentBuild = Thread.currentThread().executable
// get current build
def build = thr?.executable

def resolver = build.buildVariableResolver
def rand_value = resolver.resolve("RANDOM_NODES")
def node_value = resolver.resolve("NODE")
def label_value = resolver.resolve("LABEL_NAME")
def action = resolver.resolve("ACTION")

void remove_label(String node_name=null, String labels=null)
{
  if(node_name == null || node_name == "" || labels == null || labels == "") {
    throw new NotAllParametersPassed()
  }
  List _labels = labels.split(' ')
  List _nodes = node_name.split(' ')
  def repl = ''

  for(String node : _nodes) {
    slave = hudson.model.Hudson.instance.slaves.find {
      slave -> slave.nodeName.equals(node)
    }
    for (String label : _labels) {
      println(label)
      label = slave.labelString.replaceAll(/(^|\W)($label)($|\W)/, "\$1$repl\$3")
      slave.setLabelString(label)
      println(label)
    }
  }
}

void add_label(String node_name=null, String labels=null)
{
  if(node_name == null || node_name == "" || labels == null || labels == "") {
    throw new NotAllParametersPassed()
  }
  List _labels = labels.split(' ')
  List _nodes = node_name.split(' ')
  def _label = ''
  def _old_label = ''
  def pattern = ''

  for(String node : _nodes) {
    slave = hudson.model.Hudson.instance.slaves.find {
      slave -> slave.nodeName.equals(node)
    }
    println(slave.name)
    for(String label : _labels) {
      pattern = /.*\b$label\b.*/
      _old_label = slave.getLabelString()
      if(!_old_label.matches(pattern)) {
        _label = slave.getLabelString() + " " + label
        slave.setLabelString(_label)
      }
    }
  }
}

String choose_nodes(int nodes)
{
  def iter = 0
  def pick_nodes = true
  node_value = ''
  def pattern = ''
  def _slave = ''

  while(pick_nodes) {
    for (slave in hudson.model.Hudson.instance.slaves) {
      if(iter < nodes) {
        _slave = slave.name
        pattern = /.*\b$_slave\b.*/
        if(!slave.getComputer().isOffline() && !node_value.matches(pattern)) {
          // pickup online nodes only
          if(iter == 0) {
            // within first iter get IDLE nodes only.
            if(slave.getComputer().countBusy() < 1) {
              node_value += slave.name + ' '
            }
          } else {
            node_value += slave.name + ' '
          }
        }
      } else {
        pick_nodes = false
        break
      }
    }
    iter += 1
  }
  println("Choosen Nodes are: " + node_value)
  return node_value
}

if(rand_value == true) {
  if(node_value.isNumber()) {
      node_value = choose_nodes(node_value.toInteger())
    } else {
      throw new NotAllParametersPassed()
    }
}

if(action == "ADD_LABEL") {
  add_label(node_value, label_value)
}
else if (action == "REMOVE_LABEL") {
  remove_label(node_value, label_value)
}
else {
  throw new NotAllParametersPassed()
}

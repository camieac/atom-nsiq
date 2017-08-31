AtomNsiqView = require './atom-nsiq-view'
{CompositeDisposable} = require 'atom'
{BufferedProcess} = require('atom')
{MessagePanelView, LineMessageView} = require 'atom-message-panel'



module.exports = AtomNsiq =
  atomNsiqView: null
  modalPanel: null
  subscriptions: null

  # Configuration schema
  config:
    nsiq_path:
      title: 'Style Checker Path'
      description: 'Fully qualified path to nsiqcppstyle executable.'
      type: 'string'
      default: '/home/joe/git/nsiqcppstyle/nsiqcppstyle'
    filterfile_path:
      title: 'Path to Filter File'
      description: 'Fully qualified path to filter file.'
      type: 'string'
      default: '/home/joe/git/nsiqcppstyle/filefilter.txt'

  activate: (state) ->
    @atomNsiqView = new AtomNsiqView(state.atomNsiqViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @atomNsiqView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-nsiq:check_style': => @check_style()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @atomNsiqView.destroy()

  serialize: ->
    atomNsiqViewState: @atomNsiqView.serialize()

  check_style: ->
    # Get the editor, so we can use some of its properties
    editor = atom.workspace.getActiveTextEditor()

    messages = new MessagePanelView
        title: 'Results for nsiqcppstyle'

    # Get the filename of the current pane
    file = editor?.buffer.file
    filepath = file?.path

    # Make sure we actually have a document open!
    if filepath == undefined
      atom.notifications.addError("No file open for checking!", description: "A file must be open to style check a file.")
      return

    # Make sure the file is the correct language
    if !(filepath.search /^(.*\.(?!(cpp|c|h|hpp)$))?[^.]*$/)
      atom.notifications.addError("File not recognised as compatible", description: "nsiqcppstyle can only check C/C++.")
      return

    atom.notifications.addInfo( "Checking style of " + filepath)

    # Make sure we have a path to nsiqcppstyle
    command = atom.config.get('atom-nsiq.nsiq_path')

    # Make sure we have a path to a filefilter
    filterfile_path = atom.config.get('atom-nsiq.filterfile_path')
    if filterfile_path == undefined
      atom.notifications.addError("No filefilter path has been configured!")
      return

    args = ['-f ' + filterfile_path, filepath]
    stdout = (output) =>
      arr = output.split "\n"
      for line_idx in [0 .. arr.length]
        if arr[line_idx] == undefined
          break
        console.log("ln: " + arr[line_idx])
        if "Analyzing tmath.cpp" in arr[line_idx]
          console.log("YES!!")

        # Find the start of a file processing list
        if arr[line_idx].search(/Processing/) >= 0
          console.log "Big success \r\n\r\n\r\n"

        if arr[line_idx].search(/\(\d+, \d+\)/) >= 0
          console.log("Totes got it")
          match = /\(\d+, \d+\)/.exec arr[line_idx]
          line = /\d+/.exec match[0]
          col = /\d+/.exec match[0][1]
          # message = /(:\s{2})(\w+\s)+(?=\s{1}\[)/.exec arr[line_idx]
          # message = /(:\s{2})((.)+\s)+/.exec arr[line_idx]
          message = /:\s{2}(.+\s)+\s{1}/.exec arr[line_idx]
          console.log "message: " + message
          console.log "message: " + message[0]
          console.log "line number: " + line

          messages.add new LineMessageView
              line: line
              message: message[0]
              file: filepath
              preview: editor.lineTextForBufferRow(line-1)

    messages.attach()

    stderr = (err) => console.log(err)
    exit = (code) => console.log("ps -ef exited with #{code}")
    process = new BufferedProcess({command, args, stdout, exit, stderr: stderr})

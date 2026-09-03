import QtQuick
import QtQuick.Dialogs

Window {
  width: 875
  height: 600
  visible: true
  opacity: 0
  flags: Qt.Dialog

  Component.onCompleted: folderDialog.open()

  FolderDialog {
    id: folderDialog
    title: "Choose an Obsidian vault folder"
    acceptLabel: "Choose"
    onAccepted: {
      console.log("OBSISHELL_FOLDER=" + String(selectedFolder))
      Qt.quit()
    }
    onRejected: Qt.quit()
  }
}

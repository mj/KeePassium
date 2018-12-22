//  KeePassium Password Manager
//  Copyright © 2018 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

import KeePassiumLib

protocol KeyFileChooserDelegate: class {
    func keyFileChooser(_ sender: KeyFileChooserVC, didSelectFile urlRef: URLReference?)
}

class KeyFileChooserVC: UITableViewController, Refreshable {
    private enum CellID {
        static let noKeyFile = "NoKeyFileCell"
        static let keyFile = "KeyFileCell"
    }

    weak var coordinator: MainCoordinator?
    weak var delegate: KeyFileChooserDelegate?

    var keyFileRefs = [URLReference]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        self.refreshControl = refreshControl
        
        refresh()
    }

    @objc func refresh() {
        keyFileRefs = FileKeeper.shared.getAllReferences(fileType: .keyFile, includeBackup: false)
        let sortOrder = Settings.current.filesSortOrder
        keyFileRefs.sort { return sortOrder.compare($0, $1) }
        tableView.reloadData()
        
        if refreshControl?.isRefreshing ?? false {
            refreshControl?.endRefreshing()
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return keyFileRefs.count + 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row != 0 else {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.noKeyFile,
                for: indexPath)
            return cell
        }

        let cell = tableView.dequeueReusableCell(
            withIdentifier: CellID.keyFile,
            for: indexPath)
        let fileIndex = indexPath.row - 1
        let fileInfo = keyFileRefs[fileIndex].info
        cell.textLabel?.text = fileInfo.fileName
        guard !fileInfo.hasError else {
            cell.detailTextLabel?.text = fileInfo.errorMessage
            cell.detailTextLabel?.textColor = UIColor.errorMessage
            return cell
        }
        
        if let lastModifiedDate = fileInfo.modificationDate {
            let timestampString = DateFormatter.localizedString(
                from: lastModifiedDate,
                dateStyle: .long,
                timeStyle: .medium)
            cell.detailTextLabel?.text = timestampString
        } else {
            cell.detailTextLabel?.text = nil
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row > 0
    }

    override func tableView(
        _ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath
        ) -> [UITableViewRowAction]?
    {
        let removeAction = UITableViewRowAction(
            style: .destructive,
            title: LString.actionRemoveFile)
        {
            [unowned self] (rowAction, indexPath) in
            self.setEditing(false, animated: true)
            self.didPressRemoveKeyFile(at: indexPath)
        }
        return [removeAction]
    }
    
    // MARK: - Actions
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row > 0 else {
            delegate?.keyFileChooser(self, didSelectFile: nil)
            return
        }
        
        let selectedFileIndex = indexPath.row - 1
        delegate?.keyFileChooser(self, didSelectFile: keyFileRefs[selectedFileIndex])
    }
    
    @IBAction func didPressAddKeyFile(_ sender: Any) {
        coordinator?.addKeyFile()
    }
    
    func didPressRemoveKeyFile(at indexPath: IndexPath) {
        let fileIndex = indexPath.row - 1
        let fileRef = keyFileRefs[fileIndex]
        FileKeeper.shared.removeExternalReference(fileRef, fileType: .keyFile)
        refresh()
    }
}
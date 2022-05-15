//
//  DataController.swift
//  ntfy
//
//  Created by Philipp Heckel on 5/14/22.
//

import Foundation
import CoreData

class Store: ObservableObject {
    let container = NSPersistentContainer(name: "Model")
    
    init() {
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
    }
}

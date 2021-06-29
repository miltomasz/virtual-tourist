//
//  DataController.swift
//  Mooskine
//
//  Created by Kathryn Rotondo on 10/11/17.
//  Copyright © 2017 Udacity. All rights reserved.
//

import Foundation
import CoreData

class DataController {
    
    // MARK: - Dependencies
    
    let persistentContainer: NSPersistentContainer
    let backgroundContext: NSManagedObjectContext!
    
    // MARK: - Properties
    
    var viewContext:NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    
    init(modelName:String) {
        persistentContainer = NSPersistentContainer(name: modelName)
        
        backgroundContext = persistentContainer.newBackgroundContext()
    }
    
    func configureContexts() {
        viewContext.automaticallyMergesChangesFromParent = true
        backgroundContext.automaticallyMergesChangesFromParent = true
        
        backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
    }
    
    func load(completion: (() -> Void)? = nil) {
        persistentContainer.loadPersistentStores { storeDescription, error in
            guard error == nil else { fatalError(error!.localizedDescription) }
            
            self.configureContexts()
            completion?()
        }
    }
}

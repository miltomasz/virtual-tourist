//
//  PhotoUtility.swift
//  VirtualTourist
//
//  Created by Tomasz Milczarek on 02/06/2021.
//

import Foundation

class PhotoUtility {
    
    // MARK: - Configuration
    
    private enum Configuration {
        static var baseURL = "https://live.staticflickr.com/"
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    static func constructPhotoURL(_ photo: PhotoModel) -> URL? {
        return URL(string: Configuration.baseURL + "\(photo.server)/\(photo.id)_\(photo.secret).jpg")
    }
    
}

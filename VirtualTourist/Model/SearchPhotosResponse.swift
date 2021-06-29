//
//  SearchPhotosResponse.swift
//  VirtualTourist
//
//  Created by Tomasz Milczarek on 26/05/2021.
//

import Foundation

struct SearchPhotosResponse: Decodable {
    
    let photos: Photos?
    
}

struct Photos: Decodable {
    
    let page: Int
    let pages: Int
    let perpage: Int
    let total: Int
    let photo: [PhotoModel]?
    
}

struct PhotoModel: Decodable {
    
    let id: String
    let secret: String
    let server: String
    let title: String
    
}

//
//  FlickrClient.swift
//  OnTheMap
//
//  Created by Tomasz Milczarek on 10/04/2021.
//

import Foundation

class FlickrClient {
    
    enum Parameter {
        static var accountId = 0
        static var requestToken = ""
        static var sessionId: String? = ""
        static let defaultLimit = 100
        static let defaultOrder = "-updatedAt"
        static var loggedUser = ""
        static let method = "flickr.photos.search"
        static let api_key = ""
        static let radius = 1
        static let radius_units = "km"
        static let format = "json"
        static var lat = "0.0"
        static var lon = "0.0"
    }
    
    enum Endpoints {
        static let base = "https://www.flickr.com/services/rest/?"
        
        case getPhotosForLocation(_ lat: Double?, _ lon: Double?, pages: Int)
        
        var stringValue: String {
            switch self {
            case .getPhotosForLocation(let lat, let lon, let pages):
                let latitude = lat ?? 0.0
                let longitude = lon ?? 0.0
                let page = Int.random(in: 1...pages)
                
                return Endpoints.base + "method=\(Parameter.method)&api_key=\(Parameter.api_key)&lat=\(latitude)&lon=\(longitude)&radius=\(Parameter.radius)&radius_units=\(Parameter.radius_units)&format=\(Parameter.format)&nojsoncallback=1&per_page=25&page=\(page)"
            }
        }
        
        var url: URL {
            return URL(string: stringValue)!
        }
    }
    
    class func taskForGETRequest<ResponseType: Decodable>(url: URL, responseType: ResponseType.Type, completion: @escaping (ResponseType?, Error?) -> Void) -> URLSessionDataTask {
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            let responseObject = decodeJson(from: data, type: ResponseType.self)
            
            DispatchQueue.main.async {
                completion(responseObject, nil)
            }
        }
        
        task.resume()
        
        return task
    }
    
    private class func decodeJson<ResponseType: Decodable>(from data: Data, type: ResponseType.Type) -> ResponseType? {
        let decoder = JSONDecoder()
        do {
            let responseObject = try decoder.decode(type, from: data)
            return responseObject
        } catch let error {
            debugPrint("Decode json error: \(error)")
            return nil
        }
    }
    
    class func getPhotosForLocation(latitude: Double, longitude: Double, pages: Int, completion: @escaping (Photos?, Error?) -> Void) {
        taskForGETRequest(url: Endpoints.getPhotosForLocation(latitude, longitude, pages: pages).url, responseType: SearchPhotosResponse.self) { response, error in
            if let response = response {
                completion(response.photos, nil)
            } else {
                completion(nil, error)
            }
        }
    }
     
    class func getPhoto(from photoArray: [PhotoModel], completion: @escaping ([URL: Data?], Error?) -> Void) {
        var urlDataDict = [URL: Data?]()
        
        DispatchQueue.global(qos: .background).async {
            photoArray.forEach { photoModel in
                let fileUri = PhotoUtility.constructPhotoURL(photoModel)
                let fileName = fileUri?.absoluteString ?? "placeholder.png"
                
                guard let url = URL(string: fileName) else {
                    completion([:], nil)
                    return
                }
                
                let data = try? Data(contentsOf: url)
                
                urlDataDict.updateValue(data, forKey: url)
            }
            
            completion(urlDataDict, nil)
        }
    }
    
}

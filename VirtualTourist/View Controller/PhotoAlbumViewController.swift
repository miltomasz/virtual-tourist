//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Tomasz Milczarek on 21/05/2021.
//

import UIKit
import MapKit
import CoreData

enum DataSourceType {
    case placeholders(Int)
    case realItems
}

class PhotoAlbumViewController: UIViewController {
    
    // MARK: - IB
    
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var photoCollectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    
    // MARK: - Properties
    
    private let itemsPerRow: CGFloat = 3
    private let sectionInsets = UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)
    private var latitude: Double?
    private var longitude: Double?
    private var dataSourceType: DataSourceType = .realItems
    private let fileManager = FileManager.default
    
    var photoFetchedResultsController: NSFetchedResultsController<Photo>?
    var pin: Pin?
    let pinFetchRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
    var dataController: DataController?
    
    var coordinate: CLLocationCoordinate2D? {
        didSet {
            latitude = coordinate?.latitude
            longitude = coordinate?.longitude
        }
    }
    
    lazy var documentDirectoryUrl: URL? = {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return urls.last
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPhotoFetchedResultsController()
        setupNewCollectionButton()
        
        loadPhotos()
    }
    
    // MARK: - Setup
    
    private func setupPhotoFetchedResultsController() {
        guard let dataController = dataController, let photoFetchRequest = getPhotoFetchRequest(for: longitude, latitude) else { return }
        
        photoFetchedResultsController = NSFetchedResultsController(fetchRequest: photoFetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        
        photoFetchedResultsController?.delegate = self
    }
    
    private func setupNewCollectionButton() {
        newCollectionButton.isEnabled = false
    }
    
    private func loadPhotos() {
        guard let longitude = longitude, let latitude = latitude, let dataController = dataController else { return }
        
        NetworkHelper.showLoader(true, activityIndicator: activityIndicator)
        
        do {
            let pinsCount = try dataController.viewContext.count(for: pinFetchRequest)
            if pinsCount > 0 {
                guard let photoFetchRequest = getPhotoFetchRequest(for: longitude, latitude) else { return }
                
                let photosCount = try dataController.viewContext.count(for: photoFetchRequest)
                if photosCount > 0 {
                    photoFetchedResultsController = NSFetchedResultsController(fetchRequest: photoFetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
                    
                    photoFetchedResultsController?.delegate = self
                    
                    try photoFetchedResultsController?.performFetch()
                    
                    newCollectionButton.isEnabled = true
                    NetworkHelper.showLoader(false, activityIndicator: activityIndicator)
                } else {
                    FlickrClient.getPhotosForLocation(latitude: latitude, longitude: longitude, completion: handlePhotosResponse(results:error:))
                }
                
            } else {
                fatalError("Could not find the pin in DB: \(latitude) \(longitude)")
            }
        } catch {
            fatalError("Could not perform the fetch: \(error.localizedDescription)")
        }
    }
    
    private func getPhotoFetchRequest(for longitude: Double?, _ latitude: Double?) -> NSFetchRequest<Photo>? {
        guard let pin = pin else { return nil }
        
        let sortDescriptor = NSSortDescriptor(key: "creationDate", ascending: false)
        let pinPredicate = NSPredicate(format: "pin == %@", pin)

        let photoFetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        photoFetchRequest.sortDescriptors = [sortDescriptor]
        photoFetchRequest.predicate = pinPredicate
        
        return photoFetchRequest
    }
    
    private func handlePhotosResponse(results: Photos?, error: Error?) {
        guard let photos = results else {
            showNoPhotosFoundLabel()
            return
        }
        
        if let photoArray = photos.photo, !photoArray.isEmpty {
            reloadPhotoCollectionView(with: .placeholders(photoArray.count))
            savePhotos(photoArray)
        } else {
            NetworkHelper.showFailurePopup(title: "No photos found", message: error?.localizedDescription ?? "", on: self)
        }
    }
    
    private func showNoPhotosFoundLabel() {
        let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: photoCollectionView.bounds.size.width, height: photoCollectionView.bounds.size.height))
        
        messageLabel.text = "No Images"
        messageLabel.textColor = .black
        messageLabel.numberOfLines = 0;
        messageLabel.textAlignment = .center;
        messageLabel.font = UIFont(name: "TrebuchetMS", size: 18)
        messageLabel.sizeToFit()
        
        photoCollectionView.backgroundView = messageLabel
        newCollectionButton.isEnabled = true
    }
    
    private func reloadPhotoCollectionView(with dataSourceType: DataSourceType) {
        self.dataSourceType = dataSourceType
        
        photoCollectionView.reloadSections(IndexSet(integer: 0))
        photoCollectionView.reloadData()
    }
    
    private func savePhotos(_ photoArray: [PhotoModel]) {
        guard let dataController = dataController else { return }
         
        DispatchQueue.global(qos: .background).async { [weak self] in
            photoArray.forEach { image in
                let photo = Photo(context: dataController.viewContext)
                let fileUri = PhotoUtility.constructPhotoURL(image)
                
                photo.fileUri = fileUri
                photo.name = image.title
                photo.pin = self?.pin
                photo.creationDate = Date()
                
                do {
                    try dataController.viewContext.save()
                    
                    let fileName = fileUri?.absoluteString ?? "placeholder.png"
                    let localFileName = fileUri?.absoluteString.components(separatedBy: "/").last ?? "placeholder.png"
                    
                    guard let documentsUrl = self?.documentDirectoryUrl?.appendingPathComponent(localFileName),
                          let url = URL(string: fileName),
                          let data = try? Data(contentsOf: url) else { return }
                    
                    try data.write(to: documentsUrl)
                } catch {
                    debugPrint("Could not save file: \(error)")
                }
            }
            
            self?.showPhotos()
        }
    }
    
    private func showPhotos() {
        DispatchQueue.main.sync { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.photoFetchedResultsController?.performFetch()
                self.reloadPhotoCollectionView(with: .realItems)
            } catch {
                debugPrint("Could not load photos: \(error)")
            }
            
            NetworkHelper.showLoader(false, activityIndicator: self.activityIndicator)
            newCollectionButton.isEnabled = true
        }
    }
    
    private func deletePhotos(completion: (_ success: Bool) -> ()) {
        guard let longitude = longitude, let latitude = latitude,
              let dataController = dataController,
              let photoFetchRequest = getPhotoFetchRequest(for: longitude, latitude) else { return }
        
        do {
            let photos = try dataController.viewContext.fetch(photoFetchRequest)
            try photos.forEach { photo in
                let fileUri = photo.fileUri
                let localFileName = fileUri?.absoluteString.components(separatedBy: "/").last ?? "placeholder.png"
                
                guard let documentsUrl = documentDirectoryUrl?.appendingPathComponent(localFileName) else { return }
                
                try fileManager.removeItem(at: documentsUrl)
                dataController.viewContext.delete(photo)
                try dataController.viewContext.save()
            }
        } catch {
            debugPrint("Could not delete file: \(error)")
            completion(false)
        }
        
        completion(true)
    }
    
    // MARK: - Actions
    
    @IBAction func onNewCollectionTap(_ sender: Any) {
        guard let longitude = longitude, let latitude = latitude else { return }

        NetworkHelper.showLoader(true, activityIndicator: activityIndicator)
        newCollectionButton.isEnabled = false
        
        deletePhotos(completion: { success in
            guard success else {
                NetworkHelper.showLoader(false, activityIndicator: activityIndicator)
                NetworkHelper.showFailurePopup(title: "Error", message: "Could not delete files", on: self)
                newCollectionButton.isEnabled = true
                
                return
            }
            
            FlickrClient.getPhotosForLocation(latitude: latitude, longitude: longitude, completion: handlePhotosResponse(results:error:))
        })
    }

}

// MARK: - NSFetchedResultsControllerDelegate

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        photoCollectionView.performBatchUpdates(nil, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let dataController = dataController, let photoFetchedResultsController = photoFetchedResultsController else { return }
        
        let photoToDelete = photoFetchedResultsController.object(at: indexPath)
        dataController.viewContext.delete(photoToDelete)
        try? dataController.viewContext.save()
    }
    
}

// MARK: - UICollectionViewDataSource

extension PhotoAlbumViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        switch dataSourceType {
        case .placeholders:
            return 1
        case .realItems:
            if let sections = photoFetchedResultsController?.sections {
                return sections.count
            } else {
                return 1
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch dataSourceType {
        case .placeholders(let counter):
            return counter
        case .realItems:
            return photoFetchedResultsController?.sections?[section].numberOfObjects ?? 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoViewCellId", for: indexPath) as? PhotoViewCell else { return PhotoViewCell() }
        
        switch dataSourceType {
        case .placeholders:
            cell.imageView.image = UIImage(named: "placeholder")
        case .realItems:
            guard let photo = photoFetchedResultsController?.object(at: indexPath), let photoFileUri = photo.fileUri else { return PhotoViewCell() }
            
            let localFileName = photoFileUri.absoluteString.components(separatedBy: "/").last ?? "placeHolder.png"
            guard let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last?.appendingPathComponent(localFileName),  let data = try? Data(contentsOf: documentsUrl) else { return PhotoViewCell() }
                
            cell.imageView.image = UIImage(data: data)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "MapViewHeaderView", for: indexPath)

            guard let mapViewHeaderView = headerView as? MapViewHeaderView else { return UICollectionReusableView() }
            
            setupMapRegion(mapView: mapViewHeaderView.mapView)
            setupPin(mapView: mapViewHeaderView.mapView)
            
            return mapViewHeaderView
        }
        
        return UICollectionReusableView()
    }
    
    private func setupMapRegion(mapView: MKMapView) {
        if let mapRegion = UserDefaults.standard.object(forKey: "mapRegion") as? Dictionary<String, CLLocationDegrees>, let longitude = mapRegion["longitude"], let latitude = mapRegion["latitude"],
           let longitudeDelta = mapRegion["longitudeDelta"], let latitudeDelta = mapRegion["latitudeDelta"] {
            
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            let savedRegion = MKCoordinateRegion(center: center, span: span)
            
            mapView.setRegion(savedRegion, animated: true)
        }
    }
    
    private func setupPin(mapView: MKMapView) {
        guard let coordinate = coordinate else { return }
        
        mapView.removeAnnotations(mapView.annotations)
        
        var pinAnnotations = [MKPointAnnotation]()
        let pin = MKPointAnnotation()
        
        pin.coordinate = coordinate
        pinAnnotations.append(pin)
        
        mapView.addAnnotations(pinAnnotations)
    }
    
}

// MARK: - UICollectionViewDelegateFlowLayout

extension PhotoAlbumViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow

        return CGSize(width: widthPerItem, height: widthPerItem)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
      return sectionInsets
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
      return sectionInsets.left
    }
    
}

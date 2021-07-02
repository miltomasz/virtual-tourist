//
//  TravelLocationsMapViewController.swift
//  VirtualTourist
//
//  Created by Tomasz Milczarek on 12/05/2021.
//

import UIKit
import MapKit
import CoreData

class TravelLocationsMapViewController: UIViewController, UIGestureRecognizerDelegate {

    // MARK: - IB
    
    @IBOutlet weak var mapView: MKMapView!
    
    // MARK: - Properties
    
    private var selectedPinCoordinate: CLLocationCoordinate2D?
    private var selectedPin: Pin?
    var dataController: DataController?
    var pins: [Pin]?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSelf()
        setupMapRegion()
        setupGestureRecognizer()
        setupPins()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let photoAlbumViewController = segue.destination as? PhotoAlbumViewController else { return }
        
        photoAlbumViewController.coordinate = selectedPinCoordinate
        photoAlbumViewController.pin = selectedPin
        photoAlbumViewController.pages = 1
        photoAlbumViewController.dataController = dataController
    }
    
    // MARK: - Setup
    
    private func setupSelf() {
        modalPresentationStyle = .fullScreen
    }
    
    private func setupMapRegion() {
        if let mapRegion = UserDefaults.standard.object(forKey: "mapRegion") as? Dictionary<String, CLLocationDegrees>, let longitude = mapRegion["longitude"], let latitude = mapRegion["latitude"],
           let longitudeDelta = mapRegion["longitudeDelta"], let latitudeDelta = mapRegion["latitudeDelta"] {
            
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            let savedRegion = MKCoordinateRegion(center: center, span: span)
            
            mapView.setRegion(savedRegion, animated: true)
        }
    }
    
    private func setupGestureRecognizer() {
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action:#selector(longTap))
        gestureRecognizer.minimumPressDuration = 1.0
        gestureRecognizer.delegate = self
        
        mapView.addGestureRecognizer(gestureRecognizer)
    }
    
    private func setupPins() {
        let fetchRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
        if let results = try? dataController?.viewContext.fetch(fetchRequest) {
            pins = results
            setupPinAnnotations(results: results)
        }
    }
    
    // MARK: - Actions

    @objc private func longTap(sender: UILongPressGestureRecognizer) {
        guard sender.state == .ended else { return }
        
        let location = sender.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
        mapView.setCenter(coordinate, animated: true)
        
        let mapRegion = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta / 1.5,
            "longitudeDelta" : mapView.region.span.longitudeDelta / 1.5
        ]
        
        UserDefaults.standard.set(mapRegion, forKey: "mapRegion")
        
        guard let dataController = dataController else { return }
        
        let pin = Pin(context: dataController.viewContext)
        pin.latitude = coordinate.latitude
        pin.longitude = coordinate.longitude
        pin.creationDate = Date()
        
        do {
            try dataController.viewContext.save()
            pins?.append(pin)
        } catch {
            debugPrint("Could not save the pin: \(error)")
        }
    }
    
    private func setupPinAnnotations(results: [Pin]) {
        mapView.removeAnnotations(mapView.annotations)
        
        let pins = createPinAnnotations(for: results)
        
        mapView.addAnnotations(pins)
    }
    
    private func createPinAnnotations(for collection: [Pin]) -> [MKPointAnnotation] {
        var pinAnnotations = [MKPointAnnotation]()
        
        for result in collection {
            let lat = CLLocationDegrees(result.latitude)
            let long = CLLocationDegrees(result.longitude)
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
            
            let pin = MKPointAnnotation()
            pin.coordinate = coordinate
            
            pinAnnotations.append(pin)
        }
        
        return pinAnnotations
    }
    
}

// MARK: - MKMapViewDelegate

extension TravelLocationsMapViewController: MKMapViewDelegate {
    
    // MARK: - MKMapViewDelegate
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView

        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.pinTintColor = .red
        } else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let dataController = dataController, let coordinate = view.annotation?.coordinate else { return }
        
        selectedPinCoordinate = view.annotation?.coordinate
        let fetchSelectedPinRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "creationDate", ascending: false)
        
        fetchSelectedPinRequest.predicate = NSPredicate(format: "latitude == %lf AND longitude == %lf", coordinate.latitude, coordinate.longitude)
        fetchSelectedPinRequest.sortDescriptors = [sortDescriptor]
        
        do {
            let fetchedPins = try dataController.viewContext.fetch(fetchSelectedPinRequest)
            selectedPin = fetchedPins.first
        } catch let error {
            debugPrint("Error fetching pin: \(error)")
        }
        
        let selectedAnnotations = mapView.selectedAnnotations
        for annotation in selectedAnnotations {
            mapView.deselectAnnotation(annotation, animated: false)
        }
        
        performSegue(withIdentifier: "showPhotoAlbum", sender: nil)
    }
    
}


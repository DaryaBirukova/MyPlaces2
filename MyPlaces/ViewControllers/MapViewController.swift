//
//  MapViewController.swift
//  MyPlaces
//
//  Created by Дарья Бирюкова on 30.09.2022.
//

import UIKit
import MapKit
import CoreLocation

protocol MapViewControllerDelegate {
    func getAddress(_ address: String?)
}

class MapViewController: UIViewController {
    
    let mapManager = MapManager()
    var mapViewControllerDelegate: MapViewControllerDelegate?
    var place = Place() //создаем переменную, из кот.будем брать параметры для отображения на карте
    
    let annotationIdentifier = "annotationIdentifier"
    var incomeSegueIdentifier = ""
    var previousLocation: CLLocation? {
        didSet {
            mapManager.startTrackingUserLocation(for: mapView,
                                                 and: previousLocation) { currentLocation in
                self.previousLocation = currentLocation
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.mapManager.showUserLocation(mapView: self.mapView)
                }
            }
        }
    }

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var mapPinImage: UIImageView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var goButton: UIButton!
  
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addressLabel.text = ""
        mapView.delegate = self
        setupMapView()
    }

    @IBAction func centerViewInUserLocation() { //центрирование по местоположению пользователя
        mapManager.showUserLocation(mapView: mapView)
    }
    
    @IBAction func doneButtonPressed() {
        mapViewControllerDelegate?.getAddress(addressLabel.text)
        dismiss(animated: true)
    }
    
    @IBAction func goButtonPressed() {
        mapManager.getDirections(for: mapView) { (location) in
            self.previousLocation = location
        }
    }
    
    @IBAction func closeVC() {
        dismiss(animated: true) //закрытие MapVC
    }
    
    private func setupMapView() {
        
        goButton.isHidden = true
        
        mapManager.checkLocationServices(mapView: mapView, segueIdentifier: incomeSegueIdentifier) {
            mapManager.locationManager.delegate = self
        }
        
        if incomeSegueIdentifier == "showPlace" {
            mapManager.setupPlacemark(place: place, mapView: mapView)
            mapPinImage.isHidden = true
            addressLabel.isHidden = true
            doneButton.isHidden = true
            goButton.isHidden = false
        }
    }
}

extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil } //если маркером на карте явл.текущ.местонахождение польз-ля,то мы не создаем никакой аннотации
        
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: annotationIdentifier) as? MKPinAnnotationView
        
        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation,
                                                 reuseIdentifier: annotationIdentifier)
            annotationView?.canShowCallout = true //отображение аннотации в виде баннера
        }
        
        if let imageData = place.imageData {
            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) //добавление в баннер изображения объекта
            imageView.layer.cornerRadius = 10
            imageView.clipsToBounds = true
            imageView.image = UIImage(data: imageData)
            annotationView?.rightCalloutAccessoryView = imageView //отображение на баннере
        }
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) { // отображение адреса в центре текущего региона
        
        let center = mapManager.getCenterLocation(for: mapView) // определим текущие координаты по центру отображаемой области
        let geocoder = CLGeocoder() // экземеляр класса, кот. отвечает за преобразование географ.координат
        
        if incomeSegueIdentifier == "showPlace" && previousLocation != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.mapManager.showUserLocation(mapView: self.mapView)
            }
        }
        
        geocoder.cancelGeocode() //отмена отлож-го запроса, для освобождения ресурсов, связ. с геоколированием
        
        geocoder.reverseGeocodeLocation(center) { placemarks, error in
            if let error = error { //если обнаружена ошибка
                print(error)
                return
            }
            guard let placemarks = placemarks else { return } //извлекаем массив меток
            
            let placemark = placemarks.first //извлекаем только одну ветку
            let streetName = placemark?.thoroughfare
            let buildNumber = placemark?.subThoroughfare
            
            DispatchQueue.main.async {
                
                if streetName != nil && buildNumber != nil {
                    self.addressLabel.text = "\(streetName!), \(buildNumber!)" //передаем улицу и номер дома в label
                } else if streetName != nil {
                    self.addressLabel.text = "\(streetName!)"
                } else {
                    self.addressLabel.text = ""
                }
                
            }
        }
    }
    
    //тк построенный маршрут на экране не виден, создаем линию на карте
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        let renderer = MKPolylineRenderer(overlay: overlay as! MKPolyline) //рендеринг наложения, кот.сделали ранее
        renderer.strokeColor = .blue
        return renderer
    }
}

extension MapViewController: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        mapManager.checkLocationAuthorization(mapView: mapView,
                                              segueIdentifier: incomeSegueIdentifier)
    }
}

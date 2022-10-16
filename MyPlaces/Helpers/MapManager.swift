//
//  MapManager.swift
//  MyPlaces
//
//  Created by Дарья Бирюкова on 12.10.2022.
//

import UIKit
import MapKit

class MapManager {
    
    let locationManager = CLLocationManager() //данный класс отвечает за настройку и управление службами геолокации
    
    private var placeCoordinate: CLLocationCoordinate2D?
    private let regionInMetres = 1000.00
    private var directionsArray: [MKDirections] = [] //массив построенных маршрутов
    
    // Маркер заведения
    func setupPlacemark(place: Place, mapView: MKMapView) {
        guard let location = place.location else { return }
        
        let geocoder = CLGeocoder() //данный класс позволяет преобразовать координаты широты и долготы в польз-й вид
        geocoder.geocodeAddressString(location) { placemarks, error in
            if let error = error {
                print(error)
                return
            }
            guard let placemarks = placemarks else { return }
            let placemark = placemarks.first //получение метки на карте
            
            let annotation = MKPointAnnotation() //описание точки на карте
            annotation.title = place.name
            annotation.subtitle = place.type
            
            guard let placemarkLocation = placemark?.location else { return }
            annotation.coordinate = placemarkLocation.coordinate
            self.placeCoordinate = placemarkLocation.coordinate
            
            mapView.showAnnotations([annotation], animated: true) //задаем видимую область карты так,чтобы были видны все созданные аннотации
            mapView.selectAnnotation(annotation, animated: true) //выделяем созданную аннотацию
        }
    }
    
    // Проверка доступности сервисов геолокации
    func checkLocationServices(mapView: MKMapView, segueIdentifier: String, closure: () -> ()) {
       
        if CLLocationManager.locationServicesEnabled() {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest //точность определения геопозиции
            checkLocationAuthorization(mapView: mapView, segueIdentifier: segueIdentifier)
            closure()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { //откладываем вызов алерт контроллера на 1 сек
                self.showAlert(
                    title: "Location services are disabled",
                    message: "To enable it go: Settings - Privacy - Location services and turn it on")
            }
        }
    }
    
    // Проверка авторизации приложения для использования сервисов геолокации
    func checkLocationAuthorization(mapView: MKMapView, segueIdentifier: String) {
        switch CLLocationManager.authorizationStatus() {
            
        case .notDetermined: //пользователь еще не выбрал
            locationManager.requestWhenInUseAuthorization()
        case .restricted: //приложение не авторизовано для использования служб геолокации
            break
        case .denied:
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.showAlert(
                    title: "Location services are disabled",
                    message: "To enable it go: Settings - Privacy - Location services and turn it on")
            }
            break
        case .authorizedAlways:
            break
        case .authorizedWhenInUse:
            mapView.showsUserLocation = true
            if segueIdentifier == "getAddress" { showUserLocation(mapView: mapView) }
            break
        @unknown default:
            print("New case is available")
        }
    }
    
    func showUserLocation(mapView: MKMapView) {
        
        if let location = locationManager.location?.coordinate {
            let region = MKCoordinateRegion(center: location,
                                            latitudinalMeters: regionInMetres,
                                            longitudinalMeters: regionInMetres) //определение радиуса
            mapView.setRegion(region, animated: true) //устанавливаем регион для отображения на экране
        }
    }
    
    // Построение маршрута от местоположения пользователя к заведению
    func getDirections(for mapView: MKMapView, previousLocation: (CLLocation) -> ()) {
        
        //определяем текущую локацию
        guard let location = locationManager.location?.coordinate else {
            showAlert(title: "Error", message: "Current location is not found")
            return
        }
        
        locationManager.startUpdatingLocation()
        previousLocation(CLLocation(latitude: location.latitude, longitude: location.longitude))
        
        // выполнение запроса на прокладку маршрута
        guard let request = createDirectionsRequest(from: location) else {
            showAlert(title: "Error", message: "Destination is not found")
            return
        }
        
        let directions = MKDirections(request: request)
        resetMapView(withNew: directions, mapView: mapView)
        
        //расчет маршрута
        directions.calculate { response, error in
            
            if let error = error {
                print(error)
                return
            }
            
            //пробуем извлечь обработанный маршрут
            guard let response = response else {
                self.showAlert(title: "Error", message: "Directions is not available")
                return
            }
            
            //перебор массива маршрутов
            for route in response.routes {
                mapView.addOverlay(route.polyline) //св-во предст-е геометрию маршрута
                mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true) //фокусируем карту,чтобы был виден весь маршрут
                
                // определяем расстояние и время в пути
                let distance = String(format: "%.1f", route.distance / 1000)
                let timeInterval = route.expectedTravelTime
                
                print("Расстояние до места: \(distance) км.")
                print("Время в пути составит: \(timeInterval) секунд.")
            }
        }
    }
    
    // Настройка запроса для расчета маршрута
    func createDirectionsRequest(from coordinate: CLLocationCoordinate2D) -> MKDirections.Request? {
        
        guard let destinationCoordinate = placeCoordinate else { return nil } //координаты месты назначения
        let startingLocation = MKPlacemark(coordinate: coordinate) //определяем начало маршрута
        let destination = MKPlacemark(coordinate: destinationCoordinate) //определяем конец маршрута
        
        
        // создаем запрос на построение маршрута от точки А до точки Б
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: startingLocation)
        request.destination = MKMapItem(placemark: destination)
        request.transportType = .automobile
        request.requestsAlternateRoutes = true //позволяет строить несколько маршрутов,если есть альтернативные варианты
        
        return request
    }
    
    // Меняем отображаемую зону области карты в соответствии с перемещением пользователя
    func startTrackingUserLocation(for mapView: MKMapView, and location: CLLocation?, closure: (_ currentLocation: CLLocation) -> ()) {
        
        guard let location = location else { return }
        let center = getCenterLocation(for: mapView)
        guard center.distance(from: location) > 50 else { return }
   
        closure(center)
    }
    
    // Сброс всех ранее построенных маршрутов перед построения нового
    func resetMapView(withNew directions: MKDirections, mapView: MKMapView) {
        
        mapView.removeOverlays(mapView.overlays)
        directionsArray.append(directions)
        let _ = directionsArray.map { $0.cancel() }
        directionsArray.removeAll()
    }
    
    // Опредление центра отображаемой области карты
    func getCenterLocation(for mapView: MKMapView) -> CLLocation {
        
        let latitude = mapView.centerCoordinate.latitude // свойство, отвечающее за широту координат
        let longitude = mapView.centerCoordinate.longitude // свойство, отвечающее за долготу
        
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    
    private func showAlert(title: String, message: String) { //создание алерта
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default)
        
        alert.addAction(okAction)
        
        let alertWindow = UIWindow(frame: UIScreen.main.bounds)
        alertWindow.rootViewController = UIViewController()
        alertWindow.windowLevel = UIWindow.Level.alert + 1 //позиционирования окна относительно остальных
        alertWindow.makeKeyAndVisible() //делаем окно ключевым и видимым
        alertWindow.rootViewController?.present(alert, animated: true)
    }
}

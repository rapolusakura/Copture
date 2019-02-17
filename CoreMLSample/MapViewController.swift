//
//  MapViewController.swift
//  CoreMLSample
//
//  Created by Sakura Rapolu on 2/16/19.
//  Copyright © 2019 杨萧玉. All rights reserved.
//

import Foundation
import UIKit
import MapKit

class MapViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let viewRegion = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2D(latitude: CLLocationDegrees(41.893661957), longitude: CLLocationDegrees( -87.712942355)), 500, 500)
        self.mapView.setRegion(viewRegion, animated: false)
    }

}

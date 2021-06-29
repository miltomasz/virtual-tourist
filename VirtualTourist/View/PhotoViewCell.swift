//
//  PhotoViewCell.swift
//  VirtualTourist
//
//  Created by Tomasz Milczarek on 24/05/2021.
//

import UIKit

class PhotoViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        imageView.image = nil
    }
    
}

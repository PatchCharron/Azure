# I can never remember the right order to find the offer, sku, publisher.

#Putting the Audiocodes image here because thats the last time I had to do this for a Terraform plan


#Find offers
Get-AzVMImageOffer -Location "usgovvirginia" -PublisherName "audiocodes"
#Find SKUs
Get-AzVMImageSku -PublisherName "audiocodes" -Location "usgovvirginia" -Offer "audcovoc"
#Find Versions
Get-AzVMImage -PublisherName "audiocodes" -Location "usgovvirginia" -Offer "audcovoc" -Skus "acovoce4azure"
#Find plan info
Get-AzVMImage -PublisherName "audiocodes" -Location "usgovvirginia" -Offer "audcovoc" -Skus "acovoce4azure" -Version "8.0.2546"

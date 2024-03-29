# Purpose: Create a seried of spreadsheets of geotagged photo data from Flickr using R.
# Results based on search dates and bounding boxes (minimum latitude, minimum longitude, 
#                                                 maximum latitude, maximum longitude).


# Install and require necessary R packages.
library (rjson)
library(RJSONIO)

# Set working directory with path name in quoation marks and / instead of \
setwd("YOUR_WORK_DIRECTORY")
grid <- read.csv('YOUR_GRID_COORDINATES.csv')

#-----------------------------------------------------------------------------------------------------

Flickr_return <-function(x){
# Flicker API access keys 
# Key must have quotations around them
# Example: 'A8MNR7997LLOP123'
api_key = 'YOUR_API_KEY'
api_secret = 'YOUR_API_SECRET'

# Create function to return URL using flickr.photos.search 
# More information at https://www.flickr.com/services/api/flickr.photos.search.html
getURL = function(api_key, minDate, maxDate, minLon, minLat, maxLon, maxLat, pageNum){
  root = 'https://api.flickr.com/services/rest/?method=flickr.photos.search&'
  u = paste0(root,"api_key=",api_key, "&min_taken_date=",  minDate,"&max_taken_date=", maxDate,"&bbox=", minLon,"%2C+", minLat, "%2C+", maxLon, "%2C+", maxLat,
             "&has_geo=1&extras=description%2C+geo%2C+date_taken%2C+date_upload%2C+views%2C+tags%2c+url_o&per_page=250&page=",
             pageNum, "&format=json&nojsoncallback=1" )
  return(URLencode(u))
}

#Create function to return URL to get Exif data from image metadata
getURL2 = function(api_key, id, secret){
  root2 = 'https://api.flickr.com/services/rest/?method=flickr.photos.getExif&'
  u2 = paste0(root2,"api_key=",api_key,"&photo_id=",id,"&secret=",secret,"&format=json&nojsoncallback=1" )
  return(URLencode(u2))
}


# Set location search parameters using each grid cell extent.
minLon = grid$left[k]
minLat = grid$bottom[k]
maxLon = grid$right[k]
maxLat = grid$top[k]

# Set date search parameters.
# Use date format 'YYYY-MM-DD' with quotations. 
minDate = 'start_date'
maxDate ='end_date'

#First call for specified date and bbox
##This will return the URL that contains the information based on search variables above
##The remainder of the code will then read through the information and write it to a data frame
getURL(api_key, minDate, maxDate, minLon, minLat, maxLon, maxLat, pageNum=1)

#Read data returned from first call 
target = getURL(api_key, minDate, maxDate, minLon, minLat, maxLon, maxLat, pageNum=1)
data = fromJSON(target)

# Get the total number of photo records returned using the current search parameters.
total = as.numeric(data$photos$total) 

# Number of pages of records returned using search parameters.
numPages = data$photos$pages 

# Create empty dataframe to populate with data.
df = NULL 
# For each page of results, from the first to maximum page number extract photo information.
for (j in 1:numPages){  
  pageNum = j 
  target.loop = getURL(api_key, minDate, maxDate, minLon, minLat, maxLon, maxLat, pageNum)
  data1 = fromJSON(target.loop)
  numPhotos = length(data1$photos$photo)
  if (numPhotos==0){
      print(paste0(grid$id[k],'.....empty'))
      next()}
  else{
  # Read photo information for each photo on the current page.
    for (i in 1:numPhotos){ 
      id = data1$photos$photo[[i]]$id
      title = data1$photos$photo[[i]]$title
      lat = data1$photos$photo[[i]]$latitude
      lon = data1$photos$photo[[i]]$longitude
      owner = data1$photos$photo[[i]]$owner
      taken = data1$photos$photo[[i]]$datetaken
      dateupload = data1$photos$photo[[i]]$dateupload
      description = data1$photos$photo[[i]]$description
    
    
    # Convert UNIX epoch to date-time.
      upload = as.character.Date(as.POSIXct(as.numeric(dateupload), origin="1970-01-01"))
      views = data1$photos$photo[[i]]$views
      tags = data1$photos$photo[[i]]$tags
      secret = data1$photos$photo[[i]]$secret
      server = data1$photos$photo[[i]]$server 
      farm = data1$photos$photo[[i]]$farm
      imageURL = paste("https://farm", farm, ".staticflickr.com/", server, "/", id, "_", secret, ".jpg", sep="")
      getURL2(api_key, id, secret)
      target2 = getURL2(api_key, id, secret)
      exifData = fromJSON(target2)
    
      if (exifData$stat!="fail") {
      device = exifData$photo$camera
        } else{
      # If a value is not provided, then skip.
        device='NA'
      }
      row = cbind(lon, lat, id, owner, taken, upload, views, tags, title,description, imageURL, device)
      rbind(df, row)-> df
    
      if (j + 1 < numPages) {
      pageNum = j + 1
    }     
  }
}
  write.csv(df, paste0(grid$id[k],"_cell.csv"))}
}

#------------------------------------------------------------------------------------------------------
#The next function loops over each of the grid cells and returns metadata for any images geolocated
#with that area.
for (k in 1:nrow(grid)){
  tryCatch(
    {
      (Flickr_return(k))
      readLines(con = grid, warn = FALSE)
    },  
    error = function(cond){
    return(NA)
    next()
    }
  )
}
    

    
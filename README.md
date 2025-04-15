# Grove Wine Cellar

## About

Grove Wine Cellar is a basic wine tracking iOS application designed to help wine enthusiasts find wine pairings for meals and dishes. The app provides a digital cellar where users can inventory the wines they own and query their the wines they have in to AI to get wine pairings.

## Features

- **AI Label Recognition**: Take a photo of your wine bottle label and let the app identify and auto-populate wine details using Claude Vision AI
- **Wine Tracking**: Track wine name, producer, vintage, region, varietal, color, style, and sweetness level
- **Filter and Search**: Filter your collection by color (red, white, rosé, orange) and style (still, sparkling, fortified), as well as search your inventory
- **Archive System**: Easily archive consumed wines while maintaining your historical record
- **AI Wine Sommelier**: Get wine pairing suggestions for specific meals or dishes from your wine inventory, powered by AI

## Screenshots

<img src="https://github.com/user-attachments/assets/574f137c-2d49-4f5b-b347-a5a175b2320b" width="250"> <img src="https://github.com/user-attachments/assets/60550aa1-b602-4f1e-b282-a107e7dbc2db" width="250"> <img src="https://github.com/user-attachments/assets/1c6b2411-8509-419e-bb41-338f11788ac6" width="250">
<img src="https://github.com/user-attachments/assets/f8305551-9cfd-42cd-8d2e-994c4e6d6a61" width="250">



## Technical Details

- Written in Swift using SwiftUI
- Uses Core Data for local storage of wine information
- Camera integration for wine label photos
- Image storage with efficient compression
- Uses Claude API for vision and LLM querying

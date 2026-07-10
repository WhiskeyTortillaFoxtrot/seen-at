import Foundation

struct VenueInfo {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}

enum VenueDirectory {
    static let all: [String: VenueInfo] = [
        // MLB
        "Angel Stadium": VenueInfo(name: "Angel Stadium", address: "2000 E Gene Autry Way, Anaheim, CA 92806", latitude: 33.8003, longitude: -117.8827),
        "Chase Field": VenueInfo(name: "Chase Field", address: "401 E Jefferson St, Phoenix, AZ 85004", latitude: 33.4454, longitude: -112.0668),
        "Citizens Bank Park": VenueInfo(name: "Citizens Bank Park", address: "1 Citizens Bank Way, Philadelphia, PA 19148", latitude: 39.9056, longitude: -75.1666),
        "Citi Field": VenueInfo(name: "Citi Field", address: "41 Seaver Way, Queens, NY 11368", latitude: 40.7571, longitude: -73.8458),
        "Comerica Park": VenueInfo(name: "Comerica Park", address: "2100 Woodward Ave, Detroit, MI 48201", latitude: 42.3390, longitude: -83.0488),
        "Coors Field": VenueInfo(name: "Coors Field", address: "2001 Blake St, Denver, CO 80205", latitude: 39.7559, longitude: -104.9942),
        "Dodger Stadium": VenueInfo(name: "Dodger Stadium", address: "1000 Vin Scully Ave, Los Angeles, CA 90012", latitude: 34.0739, longitude: -118.2400),
        "Fenway Park": VenueInfo(name: "Fenway Park", address: "4 Jersey St, Boston, MA 02215", latitude: 42.3467, longitude: -71.0972),
        "Globe Life Field": VenueInfo(name: "Globe Life Field", address: "734 Stadium Dr, Arlington, TX 76011", latitude: 32.7473, longitude: -97.0832),
        "Great American Ball Park": VenueInfo(name: "Great American Ball Park", address: "100 Joe Nuxhall Way, Cincinnati, OH 45202", latitude: 39.0973, longitude: -84.5068),
        "Guaranteed Rate Field": VenueInfo(name: "Guaranteed Rate Field", address: "333 W 35th St, Chicago, IL 60616", latitude: 41.8300, longitude: -87.6339),
        "Kauffman Stadium": VenueInfo(name: "Kauffman Stadium", address: "1 Royal Way, Kansas City, MO 64129", latitude: 39.0515, longitude: -94.4803),
        "loanDepot park": VenueInfo(name: "loanDepot park", address: "501 Marlins Way, Miami, FL 33125", latitude: 25.7781, longitude: -80.2197),
        "American Family Field": VenueInfo(name: "American Family Field", address: "1 Brewers Way, Milwaukee, WI 53214", latitude: 43.0283, longitude: -87.9713),
        "Minute Maid Park": VenueInfo(name: "Minute Maid Park", address: "501 Crawford St, Houston, TX 77002", latitude: 29.7572, longitude: -95.3556),
        "Nationals Park": VenueInfo(name: "Nationals Park", address: "1500 S Capitol St SE, Washington, DC 20003", latitude: 38.8729, longitude: -77.0074),
        "Oakland Coliseum": VenueInfo(name: "Oakland Coliseum", address: "7000 Coliseum Way, Oakland, CA 94621", latitude: 37.7516, longitude: -122.2005),
        "Oracle Park": VenueInfo(name: "Oracle Park", address: "24 Willie Mays Plaza, San Francisco, CA 94107", latitude: 37.7786, longitude: -122.3893),
        "Oriole Park at Camden Yards": VenueInfo(name: "Oriole Park at Camden Yards", address: "333 W Camden St, Baltimore, MD 21201", latitude: 39.2839, longitude: -76.6216),
        "Petco Park": VenueInfo(name: "Petco Park", address: "100 Park Blvd, San Diego, CA 92101", latitude: 32.7076, longitude: -117.1571),
        "PNC Park": VenueInfo(name: "PNC Park", address: "115 Federal St, Pittsburgh, PA 15212", latitude: 40.4469, longitude: -80.0057),
        "Progressive Field": VenueInfo(name: "Progressive Field", address: "2401 Ontario St, Cleveland, OH 44115", latitude: 41.4961, longitude: -81.6853),
        "Rogers Centre": VenueInfo(name: "Rogers Centre", address: "1 Blue Jays Way, Toronto, ON M5V 1J1, Canada", latitude: 43.6414, longitude: -79.3894),
        "T-Mobile Park": VenueInfo(name: "T-Mobile Park", address: "1250 1st Ave S, Seattle, WA 98134", latitude: 47.5914, longitude: -122.3327),
        "Target Field": VenueInfo(name: "Target Field", address: "1 Twins Way, Minneapolis, MN 55403", latitude: 44.9817, longitude: -93.2783),
        "Tropicana Field": VenueInfo(name: "Tropicana Field", address: "1 Tropicana Dr, St. Petersburg, FL 33705", latitude: 27.7683, longitude: -82.6534),
        "Truist Park": VenueInfo(name: "Truist Park", address: "755 Battery Ave SE, Atlanta, GA 30339", latitude: 33.8908, longitude: -84.4683),
        "Wrigley Field": VenueInfo(name: "Wrigley Field", address: "1060 W Addison St, Chicago, IL 60613", latitude: 41.9484, longitude: -87.6553),
        "Yankee Stadium": VenueInfo(name: "Yankee Stadium", address: "1 E 161st St, Bronx, NY 10451", latitude: 40.8296, longitude: -73.9262),
        "Busch Stadium": VenueInfo(name: "Busch Stadium", address: "700 Clark Ave, St. Louis, MO 63102", latitude: 38.6226, longitude: -90.1928),

        // NBA
        "State Farm Arena": VenueInfo(name: "State Farm Arena", address: "1 State Farm Dr, Atlanta, GA 30303", latitude: 33.7573, longitude: -84.3960),
        "TD Garden": VenueInfo(name: "TD Garden", address: "100 Legends Way, Boston, MA 02114", latitude: 42.3663, longitude: -71.0622),
        "Barclays Center": VenueInfo(name: "Barclays Center", address: "620 Atlantic Ave, Brooklyn, NY 11217", latitude: 40.6827, longitude: -73.9754),
        "Spectrum Center": VenueInfo(name: "Spectrum Center", address: "333 E Trade St, Charlotte, NC 28202", latitude: 35.2250, longitude: -80.8390),
        "United Center": VenueInfo(name: "United Center", address: "1901 W Madison St, Chicago, IL 60612", latitude: 41.8806, longitude: -87.6742),
        "Rocket Mortgage FieldHouse": VenueInfo(name: "Rocket Mortgage FieldHouse", address: "1 Center Ct, Cleveland, OH 44115", latitude: 41.4964, longitude: -81.6884),
        "American Airlines Center": VenueInfo(name: "American Airlines Center", address: "2500 Victory Ave, Dallas, TX 75219", latitude: 32.7905, longitude: -96.8103),
        "Ball Arena": VenueInfo(name: "Ball Arena", address: "1000 Chopper Cir, Denver, CO 80204", latitude: 39.7486, longitude: -105.0075),
        "Little Caesars Arena": VenueInfo(name: "Little Caesars Arena", address: "2645 Woodward Ave, Detroit, MI 48201", latitude: 42.3408, longitude: -83.0549),
        "Chase Center": VenueInfo(name: "Chase Center", address: "1 Warriors Way, San Francisco, CA 94158", latitude: 37.7679, longitude: -122.3876),
        "Toyota Center": VenueInfo(name: "Toyota Center", address: "1510 Polk St, Houston, TX 77002", latitude: 29.7508, longitude: -95.3622),
        "Gainbridge Fieldhouse": VenueInfo(name: "Gainbridge Fieldhouse", address: "125 S Pennsylvania St, Indianapolis, IN 46204", latitude: 39.7639, longitude: -86.1558),
        "Crypto.com Arena": VenueInfo(name: "Crypto.com Arena", address: "1111 S Figueroa St, Los Angeles, CA 90015", latitude: 34.0430, longitude: -118.2672),
        "FedExForum": VenueInfo(name: "FedExForum", address: "191 Beale St, Memphis, TN 38103", latitude: 35.1381, longitude: -90.0506),
        "Kaseya Center": VenueInfo(name: "Kaseya Center", address: "601 Biscayne Blvd, Miami, FL 33132", latitude: 25.7814, longitude: -80.1870),
        "Fiserv Forum": VenueInfo(name: "Fiserv Forum", address: "1111 Vel R. Phillips Ave, Milwaukee, WI 53203", latitude: 43.0450, longitude: -87.9180),
        "Target Center": VenueInfo(name: "Target Center", address: "600 1st Ave N, Minneapolis, MN 55403", latitude: 44.9795, longitude: -93.2761),
        "Smoothie King Center": VenueInfo(name: "Smoothie King Center", address: "1501 Dave Dixon Dr, New Orleans, LA 70113", latitude: 29.9490, longitude: -90.0821),
        "Madison Square Garden": VenueInfo(name: "Madison Square Garden", address: "4 Pennsylvania Plaza, New York, NY 10001", latitude: 40.7505, longitude: -73.9934),
        "Paycom Center": VenueInfo(name: "Paycom Center", address: "100 W Reno Ave, Oklahoma City, OK 73102", latitude: 35.4634, longitude: -97.5151),
        "Kia Center": VenueInfo(name: "Kia Center", address: "400 W Church St, Orlando, FL 32801", latitude: 28.5389, longitude: -81.3841),
        "Wells Fargo Center": VenueInfo(name: "Wells Fargo Center", address: "3601 S Broad St, Philadelphia, PA 19148", latitude: 39.9010, longitude: -75.1719),
        "Footprint Center": VenueInfo(name: "Footprint Center", address: "201 E Jefferson St, Phoenix, AZ 85004", latitude: 33.4455, longitude: -112.0713),
        "Moda Center": VenueInfo(name: "Moda Center", address: "1 N Center Ct St, Portland, OR 97227", latitude: 45.5316, longitude: -122.6668),
        "Golden 1 Center": VenueInfo(name: "Golden 1 Center", address: "500 David J Stern Walk, Sacramento, CA 95814", latitude: 38.5803, longitude: -121.4997),
        "Frost Bank Center": VenueInfo(name: "Frost Bank Center", address: "1 AT&T Center Pkwy, San Antonio, TX 78219", latitude: 29.4269, longitude: -98.4375),
        "Scotiabank Arena": VenueInfo(name: "Scotiabank Arena", address: "40 Bay St, Toronto, ON M5J 2X2, Canada", latitude: 43.6435, longitude: -79.3790),
        "Delta Center": VenueInfo(name: "Delta Center", address: "301 S Temple, Salt Lake City, UT 84101", latitude: 40.7683, longitude: -111.9011),
        "Capital One Arena": VenueInfo(name: "Capital One Arena", address: "601 F St NW, Washington, DC 20004", latitude: 38.8980, longitude: -77.0209),

        // NFL
        "State Farm Stadium": VenueInfo(name: "State Farm Stadium", address: "1 Cardinals Dr, Glendale, AZ 85305", latitude: 33.5276, longitude: -112.2626),
        "Mercedes-Benz Stadium": VenueInfo(name: "Mercedes-Benz Stadium", address: "1 AMB Dr NW, Atlanta, GA 30313", latitude: 33.7550, longitude: -84.4008),
        "M&T Bank Stadium": VenueInfo(name: "M&T Bank Stadium", address: "1101 Russell St, Baltimore, MD 21230", latitude: 39.2780, longitude: -76.6227),
        "Highmark Stadium": VenueInfo(name: "Highmark Stadium", address: "1 Bills Dr, Orchard Park, NY 14127", latitude: 42.7738, longitude: -78.7870),
        "Bank of America Stadium": VenueInfo(name: "Bank of America Stadium", address: "800 S Mint St, Charlotte, NC 28202", latitude: 35.2258, longitude: -80.8528),
        "Soldier Field": VenueInfo(name: "Soldier Field", address: "1410 Museum Campus Dr, Chicago, IL 60605", latitude: 41.8623, longitude: -87.6167),
        "Paycor Stadium": VenueInfo(name: "Paycor Stadium", address: "1 Paul Brown Stadium, Cincinnati, OH 45202", latitude: 39.0954, longitude: -84.5161),
        "Huntington Bank Field": VenueInfo(name: "Huntington Bank Field", address: "100 Alfred Lerner Way, Cleveland, OH 44114", latitude: 41.5061, longitude: -81.6995),
        "AT&T Stadium": VenueInfo(name: "AT&T Stadium", address: "1 AT&T Way, Arlington, TX 76011", latitude: 32.7473, longitude: -97.0929),
        "Empower Field at Mile High": VenueInfo(name: "Empower Field at Mile High", address: "1701 Mile High Stadium Cir, Denver, CO 80204", latitude: 39.7439, longitude: -105.0202),
        "Ford Field": VenueInfo(name: "Ford Field", address: "2000 Brush St, Detroit, MI 48226", latitude: 42.3400, longitude: -83.0456),
        "Lambeau Field": VenueInfo(name: "Lambeau Field", address: "1265 Lombardi Ave, Green Bay, WI 54304", latitude: 44.5013, longitude: -88.0622),
        "NRG Stadium": VenueInfo(name: "NRG Stadium", address: "1 NRG Pkwy, Houston, TX 77054", latitude: 29.6847, longitude: -95.4107),
        "Lucas Oil Stadium": VenueInfo(name: "Lucas Oil Stadium", address: "500 S Capitol Ave, Indianapolis, IN 46225", latitude: 39.7601, longitude: -86.1639),
        "TIAA Bank Field": VenueInfo(name: "TIAA Bank Field", address: "1 TIAA Bank Field Dr, Jacksonville, FL 32202", latitude: 30.3240, longitude: -81.6374),
        "GEHA Field at Arrowhead Stadium": VenueInfo(name: "GEHA Field at Arrowhead Stadium", address: "1 Arrowhead Dr, Kansas City, MO 64129", latitude: 39.0489, longitude: -94.4839),
        "Allegiant Stadium": VenueInfo(name: "Allegiant Stadium", address: "3333 Al Davis Way, Las Vegas, NV 89118", latitude: 36.0906, longitude: -115.1836),
        "SoFi Stadium": VenueInfo(name: "SoFi Stadium", address: "1001 S Stadium Dr, Inglewood, CA 90301", latitude: 33.9534, longitude: -118.3388),
        "Hard Rock Stadium": VenueInfo(name: "Hard Rock Stadium", address: "347 Don Shula Dr, Miami Gardens, FL 33056", latitude: 25.9580, longitude: -80.2389),
        "U.S. Bank Stadium": VenueInfo(name: "U.S. Bank Stadium", address: "401 Chicago Ave, Minneapolis, MN 55415", latitude: 44.9738, longitude: -93.2574),
        "Gillette Stadium": VenueInfo(name: "Gillette Stadium", address: "1 Patriot Pl, Foxborough, MA 02035", latitude: 42.0909, longitude: -71.2643),
        "Caesars Superdome": VenueInfo(name: "Caesars Superdome", address: "1500 Sugar Bowl Dr, New Orleans, LA 70112", latitude: 29.9509, longitude: -90.0810),
        "MetLife Stadium": VenueInfo(name: "MetLife Stadium", address: "1 MetLife Stadium Dr, East Rutherford, NJ 07073", latitude: 40.8128, longitude: -74.0743),
        "Lincoln Financial Field": VenueInfo(name: "Lincoln Financial Field", address: "1 Lincoln Financial Field Way, Philadelphia, PA 19148", latitude: 39.9008, longitude: -75.1674),
        "Acrisure Stadium": VenueInfo(name: "Acrisure Stadium", address: "100 Art Rooney Ave, Pittsburgh, PA 15212", latitude: 40.4468, longitude: -80.0158),
        "Levi's Stadium": VenueInfo(name: "Levi's Stadium", address: "4900 Marie P DeBartolo Way, Santa Clara, CA 95054", latitude: 37.4033, longitude: -121.9692),
        "Lumen Field": VenueInfo(name: "Lumen Field", address: "800 Occidental Ave S, Seattle, WA 98134", latitude: 47.5952, longitude: -122.3316),
        "Raymond James Stadium": VenueInfo(name: "Raymond James Stadium", address: "4201 N Dale Mabry Hwy, Tampa, FL 33607", latitude: 27.9759, longitude: -82.5033),
        "Nissan Stadium": VenueInfo(name: "Nissan Stadium", address: "1 Titans Way, Nashville, TN 37213", latitude: 36.1665, longitude: -86.7713),
        "Northwest Stadium": VenueInfo(name: "Northwest Stadium", address: "1600 FedEx Way, Landover, MD 20785", latitude: 38.9077, longitude: -76.8645),

        // NHL
        "Honda Center": VenueInfo(name: "Honda Center", address: "2695 E Katella Ave, Anaheim, CA 92806", latitude: 33.8075, longitude: -117.8767),
        "KeyBank Center": VenueInfo(name: "KeyBank Center", address: "1 Seymour H Knox III Plaza, Buffalo, NY 14203", latitude: 42.8750, longitude: -78.8762),
        "Scotiabank Saddledome": VenueInfo(name: "Scotiabank Saddledome", address: "555 Saddledome Rise SE, Calgary, AB T2G 2W1, Canada", latitude: 51.0375, longitude: -114.0528),
        "Lenovo Center": VenueInfo(name: "Lenovo Center", address: "1400 Edwards Mill Rd, Raleigh, NC 27607", latitude: 35.8033, longitude: -78.7217),
        "Nationwide Arena": VenueInfo(name: "Nationwide Arena", address: "200 W Nationwide Blvd, Columbus, OH 43215", latitude: 39.9692, longitude: -83.0060),
        "Rogers Place": VenueInfo(name: "Rogers Place", address: "10220 104 Ave NW, Edmonton, AB T5J 0H6, Canada", latitude: 53.5469, longitude: -113.4976),
        "Amerant Bank Arena": VenueInfo(name: "Amerant Bank Arena", address: "1 Panther Pkwy, Sunrise, FL 33323", latitude: 26.1583, longitude: -80.3256),
        "Xcel Energy Center": VenueInfo(name: "Xcel Energy Center", address: "199 W Kellogg Blvd, St Paul, MN 55102", latitude: 44.9448, longitude: -93.1012),
        "Bell Centre": VenueInfo(name: "Bell Centre", address: "1909 Avenue des Canadiens-de-Montréal, Montreal, QC H4B 5G0, Canada", latitude: 45.4960, longitude: -73.5695),
        "Bridgestone Arena": VenueInfo(name: "Bridgestone Arena", address: "501 Broadway, Nashville, TN 37203", latitude: 36.1593, longitude: -86.7784),
        "Prudential Center": VenueInfo(name: "Prudential Center", address: "25 Lafayette St, Newark, NJ 07102", latitude: 40.7336, longitude: -74.1711),
        "UBS Arena": VenueInfo(name: "UBS Arena", address: "2150 Hempstead Turnpike, Elmont, NY 11003", latitude: 40.7125, longitude: -73.7261),
        "Canadian Tire Centre": VenueInfo(name: "Canadian Tire Centre", address: "1000 Palladium Dr, Ottawa, ON K2V 1A5, Canada", latitude: 45.2965, longitude: -75.9272),
        "PPG Paints Arena": VenueInfo(name: "PPG Paints Arena", address: "1001 Fifth Ave, Pittsburgh, PA 15219", latitude: 40.4392, longitude: -79.9902),
        "SAP Center at San Jose": VenueInfo(name: "SAP Center at San Jose", address: "525 W Santa Clara St, San Jose, CA 95113", latitude: 37.3327, longitude: -121.9003),
        "Climate Pledge Arena": VenueInfo(name: "Climate Pledge Arena", address: "334 1st Ave N, Seattle, WA 98109", latitude: 47.6220, longitude: -122.3540),
        "Enterprise Center": VenueInfo(name: "Enterprise Center", address: "1401 Clark Ave, St Louis, MO 63103", latitude: 38.6262, longitude: -90.2032),
        "Amalie Arena": VenueInfo(name: "Amalie Arena", address: "401 Channelside Dr, Tampa, FL 33602", latitude: 27.9428, longitude: -82.4519),
        "Rogers Arena": VenueInfo(name: "Rogers Arena", address: "800 Griffiths Way, Vancouver, BC V6B 6G1, Canada", latitude: 49.2778, longitude: -123.1089),
        "T-Mobile Arena": VenueInfo(name: "T-Mobile Arena", address: "3780 Las Vegas Blvd S, Las Vegas, NV 89158", latitude: 36.1027, longitude: -115.1784),
        "Canada Life Centre": VenueInfo(name: "Canada Life Centre", address: "300 Portage Ave, Winnipeg, MB R3C 5S4, Canada", latitude: 49.8928, longitude: -97.1433),

        // MLS
        "Audi Field": VenueInfo(name: "Audi Field", address: "100 Potomac Ave SW, Washington, DC 20024", latitude: 38.8684, longitude: -77.0145),
        "Allianz Field": VenueInfo(name: "Allianz Field", address: "400 Snelling Ave N, St Paul, MN 55104", latitude: 44.9526, longitude: -93.1662),
        "America First Field": VenueInfo(name: "America First Field", address: "9256 S State St, Sandy, UT 84070", latitude: 40.5828, longitude: -111.8931),
        "BC Place": VenueInfo(name: "BC Place", address: "777 Pacific Blvd, Vancouver, BC V6B 4Y8, Canada", latitude: 49.2767, longitude: -123.1120),
        "BMO Field": VenueInfo(name: "BMO Field", address: "170 Princes' Blvd, Toronto, ON M6K 3C3, Canada", latitude: 43.6333, longitude: -79.4186),
        "BMO Stadium": VenueInfo(name: "BMO Stadium", address: "3939 S Figueroa St, Los Angeles, CA 90037", latitude: 34.0125, longitude: -118.2852),
        "Children's Mercy Park": VenueInfo(name: "Children's Mercy Park", address: "1 Sporting Way, Kansas City, KS 66111", latitude: 39.1216, longitude: -94.8230),
        "CITYPARK": VenueInfo(name: "CITYPARK", address: "2100 Market St, St. Louis, MO 63103", latitude: 38.6303, longitude: -90.2102),
        "Dick's Sporting Goods Park": VenueInfo(name: "Dick's Sporting Goods Park", address: "6000 Victory Way, Commerce City, CO 80022", latitude: 39.8054, longitude: -104.8919),
        "Dignity Health Sports Park": VenueInfo(name: "Dignity Health Sports Park", address: "18400 Avalon Blvd, Carson, CA 90746", latitude: 33.8637, longitude: -118.2612),
        "GEODIS Park": VenueInfo(name: "GEODIS Park", address: "501 29th Ave N, Nashville, TN 37209", latitude: 36.1652, longitude: -86.7907),
        "Inter&Co Stadium": VenueInfo(name: "Inter&Co Stadium", address: "655 W Church St, Orlando, FL 32805", latitude: 28.5409, longitude: -81.3919),
        "Lower.com Field": VenueInfo(name: "Lower.com Field", address: "96 Columbus Crew Way, Columbus, OH 43215", latitude: 39.9682, longitude: -83.0178),
        "PayPal Park": VenueInfo(name: "PayPal Park", address: "1123 Coleman Ave, San Jose, CA 95110", latitude: 37.3512, longitude: -121.9241),
        "Providence Park": VenueInfo(name: "Providence Park", address: "1844 SW Morrison St, Portland, OR 97205", latitude: 45.5215, longitude: -122.6916),
        "Q2 Stadium": VenueInfo(name: "Q2 Stadium", address: "10414 McKalla Pl, Austin, TX 78758", latitude: 30.3859, longitude: -97.7182),
        "Red Bull Arena": VenueInfo(name: "Red Bull Arena", address: "600 Cape May St, Harrison, NJ 07029", latitude: 40.7368, longitude: -74.1502),
        "Shell Energy Stadium": VenueInfo(name: "Shell Energy Stadium", address: "2200 Texas Ave, Houston, TX 77003", latitude: 29.7530, longitude: -95.3520),
        "Snapdragon Stadium": VenueInfo(name: "Snapdragon Stadium", address: "2101 Stadium Way, San Diego, CA 92108", latitude: 32.7833, longitude: -117.1179),
        "Stade Saputo": VenueInfo(name: "Stade Saputo", address: "4750 Rue Sherbrooke E, Montreal, QC H1V 3S8, Canada", latitude: 45.5631, longitude: -73.5525),
        "Subaru Park": VenueInfo(name: "Subaru Park", address: "1 Stadium Dr, Chester, PA 19013", latitude: 39.8320, longitude: -75.3784),
        "Toyota Stadium": VenueInfo(name: "Toyota Stadium", address: "9200 World Cup Way, Frisco, TX 75034", latitude: 33.1544, longitude: -96.8351),
        "TQL Stadium": VenueInfo(name: "TQL Stadium", address: "1501 Central Pkwy, Cincinnati, OH 45214", latitude: 39.1117, longitude: -84.5248),

        // LOVB
        "Gateway Center Arena": VenueInfo(name: "Gateway Center Arena", address: "2000 Convention Center Concourse, College Park, GA 30337", latitude: 33.6405, longitude: -84.4490),
        "H-E-B Center": VenueInfo(name: "H-E-B Center", address: "2100 Avenue of the Stars, Cedar Park, TX 78613", latitude: 30.5247, longitude: -97.8208),
        "Berry Center": VenueInfo(name: "Berry Center", address: "8877 Barker Cypress Rd, Cypress, TX 77433", latitude: 29.9525, longitude: -95.6494),
        "Alliant Energy Center": VenueInfo(name: "Alliant Energy Center", address: "1919 Alliant Energy Center Way, Madison, WI 53713", latitude: 43.0417, longitude: -89.3936),
        "Baxter Arena": VenueInfo(name: "Baxter Arena", address: "2425 S 67th St, Omaha, NE 68182", latitude: 41.2187, longitude: -96.0151),
        "Lifetime Activities Center": VenueInfo(name: "Lifetime Activities Center", address: "6150 S 300 W, Salt Lake City, UT 84107", latitude: 40.6374, longitude: -111.8917),
    ]

    static func info(for venueName: String) -> VenueInfo? {
        let exact = all[venueName]
        if exact != nil { return exact }
        let lowered = venueName.lowercased()
        return all.first { $0.key.lowercased() == lowered }?.value
    }

    static func homeVenue(for teamName: String) -> String? {
        switch teamName {
        // MLB
        case "Arizona Diamondbacks": "Chase Field"
        case "Atlanta Braves": "Truist Park"
        case "Baltimore Orioles": "Oriole Park at Camden Yards"
        case "Boston Red Sox": "Fenway Park"
        case "Chicago Cubs": "Wrigley Field"
        case "Chicago White Sox": "Guaranteed Rate Field"
        case "Cincinnati Reds": "Great American Ball Park"
        case "Cleveland Guardians": "Progressive Field"
        case "Colorado Rockies": "Coors Field"
        case "Detroit Tigers": "Comerica Park"
        case "Houston Astros": "Minute Maid Park"
        case "Kansas City Royals": "Kauffman Stadium"
        case "Los Angeles Angels": "Angel Stadium"
        case "Los Angeles Dodgers": "Dodger Stadium"
        case "Miami Marlins": "loanDepot park"
        case "Milwaukee Brewers": "American Family Field"
        case "Minnesota Twins": "Target Field"
        case "New York Mets": "Citi Field"
        case "New York Yankees": "Yankee Stadium"
        case "Oakland Athletics": "Oakland Coliseum"
        case "Philadelphia Phillies": "Citizens Bank Park"
        case "Pittsburgh Pirates": "PNC Park"
        case "San Diego Padres": "Petco Park"
        case "San Francisco Giants": "Oracle Park"
        case "Seattle Mariners": "T-Mobile Park"
        case "St. Louis Cardinals": "Busch Stadium"
        case "Tampa Bay Rays": "Tropicana Field"
        case "Texas Rangers": "Globe Life Field"
        case "Toronto Blue Jays": "Rogers Centre"
        case "Washington Nationals": "Nationals Park"

        // NBA
        case "Atlanta Hawks": "State Farm Arena"
        case "Boston Celtics": "TD Garden"
        case "Brooklyn Nets": "Barclays Center"
        case "Charlotte Hornets": "Spectrum Center"
        case "Chicago Bulls": "United Center"
        case "Cleveland Cavaliers": "Rocket Mortgage FieldHouse"
        case "Dallas Mavericks": "American Airlines Center"
        case "Denver Nuggets": "Ball Arena"
        case "Detroit Pistons": "Little Caesars Arena"
        case "Golden State Warriors": "Chase Center"
        case "Houston Rockets": "Toyota Center"
        case "Indiana Pacers": "Gainbridge Fieldhouse"
        case "Los Angeles Clippers": "Crypto.com Arena"
        case "Los Angeles Lakers": "Crypto.com Arena"
        case "Memphis Grizzlies": "FedExForum"
        case "Miami Heat": "Kaseya Center"
        case "Milwaukee Bucks": "Fiserv Forum"
        case "Minnesota Timberwolves": "Target Center"
        case "New Orleans Pelicans": "Smoothie King Center"
        case "New York Knicks": "Madison Square Garden"
        case "Oklahoma City Thunder": "Paycom Center"
        case "Orlando Magic": "Kia Center"
        case "Philadelphia 76ers": "Wells Fargo Center"
        case "Phoenix Suns": "Footprint Center"
        case "Portland Trail Blazers": "Moda Center"
        case "Sacramento Kings": "Golden 1 Center"
        case "San Antonio Spurs": "Frost Bank Center"
        case "Toronto Raptors": "Scotiabank Arena"
        case "Utah Jazz": "Delta Center"
        case "Washington Wizards": "Capital One Arena"

        // NFL
        case "Arizona Cardinals": "State Farm Stadium"
        case "Atlanta Falcons": "Mercedes-Benz Stadium"
        case "Baltimore Ravens": "M&T Bank Stadium"
        case "Buffalo Bills": "Highmark Stadium"
        case "Carolina Panthers": "Bank of America Stadium"
        case "Chicago Bears": "Soldier Field"
        case "Cincinnati Bengals": "Paycor Stadium"
        case "Cleveland Browns": "Huntington Bank Field"
        case "Dallas Cowboys": "AT&T Stadium"
        case "Denver Broncos": "Empower Field at Mile High"
        case "Detroit Lions": "Ford Field"
        case "Green Bay Packers": "Lambeau Field"
        case "Houston Texans": "NRG Stadium"
        case "Indianapolis Colts": "Lucas Oil Stadium"
        case "Jacksonville Jaguars": "TIAA Bank Field"
        case "Kansas City Chiefs": "GEHA Field at Arrowhead Stadium"
        case "Las Vegas Raiders": "Allegiant Stadium"
        case "Los Angeles Chargers": "SoFi Stadium"
        case "Los Angeles Rams": "SoFi Stadium"
        case "Miami Dolphins": "Hard Rock Stadium"
        case "Minnesota Vikings": "U.S. Bank Stadium"
        case "New England Patriots": "Gillette Stadium"
        case "New Orleans Saints": "Caesars Superdome"
        case "New York Giants": "MetLife Stadium"
        case "New York Jets": "MetLife Stadium"
        case "Philadelphia Eagles": "Lincoln Financial Field"
        case "Pittsburgh Steelers": "Acrisure Stadium"
        case "San Francisco 49ers": "Levi's Stadium"
        case "Seattle Seahawks": "Lumen Field"
        case "Tampa Bay Buccaneers": "Raymond James Stadium"
        case "Tennessee Titans": "Nissan Stadium"
        case "Washington Commanders": "Northwest Stadium"

        // NHL
        case "Anaheim Ducks": "Honda Center"
        case "Boston Bruins": "TD Garden"
        case "Buffalo Sabres": "KeyBank Center"
        case "Calgary Flames": "Scotiabank Saddledome"
        case "Carolina Hurricanes": "Lenovo Center"
        case "Chicago Blackhawks": "United Center"
        case "Colorado Avalanche": "Ball Arena"
        case "Columbus Blue Jackets": "Nationwide Arena"
        case "Dallas Stars": "American Airlines Center"
        case "Detroit Red Wings": "Little Caesars Arena"
        case "Edmonton Oilers": "Rogers Place"
        case "Florida Panthers": "Amerant Bank Arena"
        case "Los Angeles Kings": "Crypto.com Arena"
        case "Minnesota Wild": "Xcel Energy Center"
        case "Montreal Canadiens": "Bell Centre"
        case "Nashville Predators": "Bridgestone Arena"
        case "New Jersey Devils": "Prudential Center"
        case "New York Islanders": "UBS Arena"
        case "New York Rangers": "Madison Square Garden"
        case "Ottawa Senators": "Canadian Tire Centre"
        case "Philadelphia Flyers": "Wells Fargo Center"
        case "Pittsburgh Penguins": "PPG Paints Arena"
        case "San Jose Sharks": "SAP Center at San Jose"
        case "Seattle Kraken": "Climate Pledge Arena"
        case "St. Louis Blues": "Enterprise Center"
        case "Tampa Bay Lightning": "Amalie Arena"
        case "Toronto Maple Leafs": "Scotiabank Arena"
        case "Utah Hockey Club": "Delta Center"
        case "Vancouver Canucks": "Rogers Arena"
        case "Vegas Golden Knights": "T-Mobile Arena"
        case "Washington Capitals": "Capital One Arena"
        case "Winnipeg Jets": "Canada Life Centre"

        // LOVB
        case "LOVB Atlanta": "Gateway Center Arena"
        case "LOVB Austin": "H-E-B Center"
        case "LOVB Houston": "Berry Center"
        case "LOVB Madison": "Alliant Energy Center"
        case "LOVB Nebraska": "Baxter Arena"
        case "LOVB Salt Lake": "Lifetime Activities Center"

        // MLS
        case "Atlanta United FC": "Mercedes-Benz Stadium"
        case "Austin FC": "Q2 Stadium"
        case "CF Montréal": "Stade Saputo"
        case "Chicago Fire FC": "Soldier Field"
        case "Colorado Rapids": "Dick's Sporting Goods Park"
        case "Columbus Crew": "Lower.com Field"
        case "D.C. United": "Audi Field"
        case "FC Cincinnati": "TQL Stadium"
        case "FC Dallas": "Toyota Stadium"
        case "Houston Dynamo FC": "Shell Energy Stadium"
        case "LA Galaxy": "Dignity Health Sports Park"
        case "Los Angeles FC": "BMO Stadium"
        case "Minnesota United FC": "Allianz Field"
        case "Nashville SC": "GEODIS Park"
        case "New England Revolution": "Gillette Stadium"
        case "New York City FC": "Yankee Stadium"
        case "New York Red Bulls": "Red Bull Arena"
        case "Orlando City SC": "Inter&Co Stadium"
        case "Philadelphia Union": "Subaru Park"
        case "Portland Timbers": "Providence Park"
        case "Real Salt Lake": "America First Field"
        case "San Diego FC": "Snapdragon Stadium"
        case "San Jose Earthquakes": "PayPal Park"
        case "Seattle Sounders FC": "Lumen Field"
        case "Sporting Kansas City": "Children's Mercy Park"
        case "St. Louis CITY SC": "CITYPARK"
        case "Toronto FC": "BMO Field"
        case "Vancouver Whitecaps FC": "BC Place"
        default: nil
        }
    }
}

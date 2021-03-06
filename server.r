library(shinydashboard)
library(leaflet)
library(dplyr)
library(RPostgreSQL)
library(ggplot2)

function(input, output, session) {
    # define available layers
    wms_layers <- data.frame(layer=c("JRC-Global-Water-Bodies", "watermask"),id=c(1,2)) %>% mutate(layer=as.character(layer))


    output$mymap <- renderLeaflet({
        activelayers <- filter(wms_layers,id %in% as.numeric(input$datasets)) %>% pull(layer)
        source("/srv/shiny-server/buhayra-semiarido/pw.R")

        leaflet() %>%
            addProviderTiles(providers$OpenStreetMap.Mapnik) %>%
            setView(-36,-5.5, zoom=7) %>%
            addWMSTiles(
                paste0("http://",hostname,"/latestwms"),
                layers = activelayers,
                options = WMSTileOptions(format = "image/png",
                                         transparent = TRUE,
                                         version='1.3.0',
                                         srs='EPSG:4326')) %>%
            addScaleBar(position = "topleft")
    })

    observeEvent(input$mymap_click,
    {
        click <- input$mymap_click
        source("/srv/shiny-server/buhayra-semiarido/pw.R")
        drv <- dbDriver("PostgreSQL")
        con <- dbConnect(drv, dbname='watermasks', host = hostname, port = 5432, user = "sar2water", password = pw)
        rm(pw)
        # click = list()
        # click$lat=-5.3317
        # click$lng=-40.3075
        ts <- dbGetQuery(con, paste0("SELECT jrc_neb.id_jrc, ST_area(ST_Transform(jrc_neb.geom,32724)) as ref_area, neb.area, neb.ingestion_time, neb.wmxjrc_area FROM jrc_neb RIGHT JOIN neb ON jrc_neb.id_jrc=neb.id_jrc WHERE ST_Contains(jrc_neb.geom, ST_SetSRID(ST_Point(",click$lng,",",click$lat,"),4326))"))
        dbDisconnect(conn = con)



        if(nrow(ts) == 0)
        {

            text <- "Açude vazio ou indisponível" #required info
            leafletProxy("mymap") %>%
                clearPopups() %>%
                addPopups(click$lng, click$lat, text)
        }
        else
        {
          ts <- mutate(ts,ratio=ifelse(area==0,0,wmxjrc_area/area)) %>%
            filter(ratio>0.9)

          output$plot <- renderPlot({
              ggplot(ts) +
                  geom_point(aes(x=ingestion_time,y=area/10000)) +
                  scale_y_continuous(limits=c(0,1.1*max(ts$ref_area)/10000)) +
                  geom_hline(yintercept=ts$ref_area[1]/10000,linetype='dashed',color='orange') +
                  xlab("Data de Aquisição") +
                  ylab("Área [ha]")
          })
          text <- paste0("Área do Espelho de Água: ",
                           ts %>%
                           filter(ingestion_time == max(ingestion_time)) %>%
                           mutate(area=round(area/10000, digits = 1)) %>%
                           pull(area),
                           " ha",
                           "<br>",
                           "Data e Hora de Aquisição: ",
                           strptime(max(ts$ingestion_time),"%Y-%m-%d %H:%M:%S"),
                           "<br>",
                           "ID: ",
                           ts$id_jrc[1])
            leafletProxy("mymap") %>%
                clearPopups() %>%
                addPopups(click$lng, click$lat, text)
        }

    })


}

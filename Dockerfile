#
# Super simple dockerfile for seca-vista
#
FROM ubuntu:latest

MAINTAINER JM Delgado "martinsd@uni-potsdam.de"

FROM rocker/shiny-verse

RUN apt-get update && \
  apt-get install -y git libgdal-dev cron && \
  install2.r --error \
  rgdal \
  shinythemes \
  leaflet \
  sp \
  RPostgreSQL

RUN chmod -R 755 /srv/shiny-server && \
  mkdir /srv/shiny-server/buhayra-semiarido

RUN git clone git@github.com:jmigueldelgado/buhayra-semiarido.git /srv/shiny-server/buhayra-semiarido

COPY /home/martinsd/proj/buhayra-semiarido/pw.R /srv/shiny-server/buhayra-semiarido/pw.R

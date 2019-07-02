#!/usr/bin/env Rscript

##############################################################
#
# Using RStudio to run this code? Follow these steps:
#
# 1) Define the variable 'input.file.string' in your Rstudio shell 
#    and then all of the command-line option code will be 
#    skipped and you can run this script within RStudio!
#
#    Example command
#    input.file.string = "input1.csv,input2.csv"
#
# 2) Set the working directory to a folder on your computer
#    that contains files 'input1.csv' and 'input2.csv'
#
#   Expects these files to exist:
#      input1.csv
#      input2.csv
#
##############################################################

library(tidyverse)
library(plotly)
library(ggplot2)
library(gridExtra)
library(cowplot)
library(optparse)
library(xtable)

if (!exists("input.file.string")) {
  
  option_list = list(
    make_option(c("-i", "--input"), type="character", default=NULL, 
                help="Input file. You may separate values by commas to analyze multiple input files together", metavar="input.csv")
  )
  
  usage_string = paste(
    "summary-graph.R -i input1,input2,input3\n\n",
    sep = ""
  ) 
  
  opt_parser = OptionParser(usage=usage_string, option_list=option_list)
  opt = parse_args(opt_parser)
  
  if (is.null(opt$input)) {
    print_help(opt_parser)
    stop("You must supply the -i|--input argument for the input", call.=FALSE)
  }
  
  input.file.string = opt$input
}

## Allow loading of multiple different results
input.file.names = strsplit(input.file.string,",")

###
# Special sample names for metadata
#  "blank" well will be used to create an average blank value
#  "ignore" well will be removed before analysis

readings = c("growth", "GFP") 

all.data = data.frame()
for (this.file.name in input.file.names[[1]]) {
  
  if (tools::file_ext(this.file.name) == "csv") {
    this.data <- read_csv(this.file.name)
    output.prefix= sub(".csv", "", input.file.names[[1]][1])
  } else if (tools::file_ext(this.file.name) == "tsv") {
    this.data <- read_tsv(this.file.name)
    output.prefix= sub(".tsv", "", input.file.names[[1]][1])
  } else {
    stop(paste0("Unrecognized file extension (must be csv or tsv) for file: ", this.file.name))
  }
  
  if("graph" %in% colnames(this.data)) {
    this.data = this.data %>% filter(graph==1)
  }
  all.data = rbind(all.data, this.data)
}



all.data$replicate=as.factor(all.data$replicate)

## fit line and show entire range

fit.data = all.data
if("fit" %in% colnames(fit.data)) {
  fit.data = this.data %>% filter(fit==1)
}

fit_fixed_zero = lm(GFP.rate~growth.rate + 0, fit.data)
slope_fixed_zero = coef(fit_fixed_zero)

p = ggplot(all.data, aes_(x=as.name(paste0(readings[1], ".rate")), y=as.name(paste0(readings[2], ".rate")), color=as.name("strain"), shape=as.name("replicate")))  +
  geom_errorbarh(aes(xmin=growth.rate-growth.rate.sd, xmax=growth.rate+growth.rate.sd), height=0) +
  geom_errorbar(aes(ymin=GFP.rate-GFP.rate.sd, ymax=GFP.rate+GFP.rate.sd), width=0) + 
  geom_point(size=5)  +
  scale_x_continuous(limits = c(0, max(all.data$growth.rate+all.data$growth.rate.sd))) + 
  scale_y_continuous(limits = c(0, max(all.data$GFP.rate+all.data$GFP.rate.sd))) + 
  geom_abline(intercept=0, slope = slope_fixed_zero)

ggsave(paste0(output.prefix, ".burden_vs_growth_rates.pdf"))

p <- ggplotly(p)
htmlwidgets::saveWidget(as_widget(p), paste0(output.prefix, ".burden_vs_growth_rates.html"))

#We need to convert NA replicates to a factor number.
#all.data$replicate=factor(all.data$replicate, levels=c(1,levels(all.data$replicate)))
#all.data$replicate[is.na(all.data$replicate)] = 1

all.data$replicate=as.factor(all.data$replicate)
p = ggplot(all.data, aes_(x=as.name("strain"), y=as.name(paste0(readings[1], ".rate")), fill=as.name("replicate")))  +  geom_bar(size=3, stat="identity", position=position_dodge()) +
  geom_errorbar(aes(ymin=growth.rate-growth.rate.sd, ymax=growth.rate+growth.rate.sd), position=position_dodge()) + 
  scale_y_continuous(limits = c(0, max(all.data$growth.rate+all.data$growth.rate.sd))) + 

ggsave(paste0(output.prefix, ".growth_rates.pdf"))

p <- ggplotly(p)
htmlwidgets::saveWidget(as_widget(p), paste0(output.prefix, ".growth_rates.html"))

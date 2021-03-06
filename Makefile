# Paper

all: main.pdf.open

preprint: preprint.pdf.open

clean:
	rm *.toc *.log *.blg *.out *.pdf *.aux *.nav *.vrb *.snm *~

%.open: %
	open $<

%.pdf: %.tex paper.tex references.bib
	pdflatex $<
	bibtex $*
	pdflatex $<
	pdflatex $<

.SECONDARY:


# Analysis
WTFURL = https://github.com/evoldoers/wtfgenes.git
WTFGENES = ./wtfgenes/bin/wtfgenes.js

YEAST = wtfgenes/test/data/yeast
GO = go-basic.obo
ASSOCS = gene_association.sgd
MATING = cerevisiae-mating.txt

wtfgenes:
	git clone $(WTFURL)

$(YEAST)/$(GO) $(YEAST)/$(ASSOCS): wtfgenes
	cd $(YEAST); make $(GO) $(ASSOCS)

# The next two rules use biomake's multi-wildcard pattern-matching
# https://github.com/evoldoers/biomake
mixing.f$F-s$S-j$J-r$R.json: $(YEAST)/$(GO) $(YEAST)/$(ASSOCS)
	$(WTFGENES) -F $F -S $S -J $J -R $R -o $(YEAST)/$(GO) -a $(YEAST)/$(ASSOCS) -g $(YEAST)/$(MATING) -l mixing >$@

$(AUTO).$(PARAMS).csv: mixing.$(PARAMS).json
	node -e 'var fs = require ("fs"), json = JSON.parse (fs.readFileSync ("$<")), auto = json.mcmc.$(AUTO); if (auto[0]) auto = auto[0]; console.log ("tau,$(AUTO)"); Object.keys(auto).forEach (function (tau) { console.log (tau + "," + auto[tau]) })' >$@

KERNELS = f1-s0-j0-r0 f1-s1-j0-r0 f1-s0-j1-r0 f1-s0-j0-r1 f1-s1-j1-r0
CSV = $(patsubst %,logLikeAutoCorrelation.%.csv,$(KERNELS)) $(patsubst %,termAutoCorrelation.%.csv,$(KERNELS))

csv: $(CSV)

# R
makeplot.R:
	node -e 'var kernels = "$(KERNELS)".split(" "); console.log ("require(\"ggplot2\")"); function makePlot (v, title) { var frames = []; kernels.forEach (function (k) { var tag = k.split("-").join(""), match = /f(.*)-s(.*)-j(.*)-r(.*)/.exec(k), moves = ["flip","step","jump","randomize"], labels = []; moves.forEach (function (move, n) { if (match[n+1] !== "0") { labels.push ((match[n+1] === "1" ? "" : (match[n+1]+"*")) + move) } }); var frame = "data." + tag; frames.push(frame); console.log(frame+" = read.csv(\""+v+"."+k+".csv\")\n"+frame+"$$Kernel = \""+labels.join(" + ")+"\"\n") }); console.log("dat = rbind("+frames.join(",")+")\n\nggplot(aes(x=tau, y="+v+", color=Kernel), data=dat) + geom_line(aes(linetype=Kernel)) + geom_point(aes(shape=Kernel)) + xlim(0,1024) + ylim(0,1) + ylab(\""+title+"\") + xlab(\"Samples per term\") + theme(legend.position = c(.85,.85))\nggsave(\""+v+".pdf\")\n") } makePlot("logLikeAutoCorrelation","Log-likelihood autocorrelation"); makePlot("termAutoCorrelation","Term variable autocorrelation") ' >$@

logLikeAutoCorrelation.pdf termAutoCorrelation.pdf: makeplot.R $(CSV)
	R -f makeplot.R


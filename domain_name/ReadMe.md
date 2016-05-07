## Classifying Pornographic Domains Using Keywords and Domain Suffixes

We build a model about whether or not a particular domain carries pornographic content using a short list of keywords and a list of domain level suffixes. To build the model, we use data from [Shallalist](http://www.shallalist.de/), which maintains a database of category of content hosted by a domain. Details about the method are outlined in [Where's the Porn? Classifying Porn Domains Using a Calibrated Keyword Classifier](http://gbytes.gsood.com/2015/07/23/wheres-the-porn-classifying-porn-domains-using-a-calibrated-keyword-classifier/). 

The [classifier](shalla.md) using the following [shallalist data](shalla_cat_unique_host.csv), [list of keywords](knotty_words.txt) and [domain suffixes](https://publicsuffix.org/list/) achieves an accuracy of nearly 80\%.

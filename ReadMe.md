### Domain Classifier

Be it understanding media consumption, or segmenting domain referrals, we need to classify the content hosted on domains. 

When faced with the task, often enough, researchers resort to heuristic solutions. For instance, 

> We select an initial universe of news outlets (i.e., web domains) via the Open Directory Project (ODP, dmoz.org), a collective of tens of thousands of editors who hand-label websites into a classification hierarchy. This gives 7,923 distinct domains labeled as: news, politics/news, politics/media, and regional/news. Since the vast majority of these news sites receive relatively little traffic, to simplify our analysis we restrict to the one hundred domains that attracted the largest number of unique visitors from our sample of toolbar users. This list of popular news sites includes every major national news source, well-known blogs and many regional dailies, and collectively accounts for over 98% of page views of news sites in the full ODP list (as estimated via our toolbar sample). The complete list of 100 domains is given in the Appendix.

[Filter Bubbles, Echo Chambers, and Online News Consumption](https://5harad.com/papers/bubbles.pdf)

The solution is reasonable but unsatisfactory. For instance, we don't know the number of false positives and negatives. 

There are two simple ways to improve on such methods. One is to build a calibrated keyword classifier. Start with keywords that are good at picking URLs with particular content. And then improve and calibrate it using an API. See for instance, [Where's the Porn? Classifying Porn Domains Using a Calibrated Keyword Classifier](http://gbytes.gsood.com/2015/07/23/wheres-the-porn-classifying-porn-domains-using-a-calibrated-keyword-classifier/). Or one may simply rely on API access. See for instance, [Where's the news?: Classifying News Domains](http://gbytes.gsood.com/2015/07/23/wheres-the-news-classifying-news-domains/) for a discussion of the method and some remaining issues. 

Here below is a script to get the (dominant) type of content that is hosted on each domain using the [Trusted Source API](http://www.trustedsource.org/en/feedback/url). We apply the script to browsing data from comScore, producing a set of files that contain unique domains and the content category. We then use these data to estimate false negative rate in a prominent study using the comScore data to estimate news consumption and selective exposure. 

#### Script

The script [api_domain_classifier](api_domain_classifier.py) takes a csv with a column of domain names ([sample input](sample_in.csv)) and appends a column containing the content category according to [Trusted Source](http://www.trustedsource.org/en/feedback/url) ([sample output](sample_out.csv)). The script is very modestly tailored towards large files in the following manner: If you have a large input file, you would ideally want to split the file and run multiple scripts in parallel across potentially different servers. To ease collation of the final data, the script defaults to an output file name that tracks what portion of the file is being processed of the whole. So the output file for 1 of 8 parts will be named `url_category_part_1_8` by default. The two command line arguments `current_part`, and `total_parts` are **neccessary**. For cases where file hasn't been split, just pass 1 1. For example:
```
python api_domain_classifier.py 1 1  
```
Other than the neccessary command line options, following options (within the script) can be tweaked:  
* INPUT_FILE: Path to the Input file (Line 7)
* URL_COLUMN_NAME: name of the url column (Line 8)
* URL_CATEGORY_COLUMN_NAME: name of the url_catefoty column name in outputfile (Line 9)
* FINAL_OUTPUT_FILE: name of the final output file (Line 22)

#### Data

To make it easier for researchers to exploit the comScore data, we provide categories for all unique domains in the comScore datasets. (Academic users can access the comScore browsing data from the [Wharton Research Data Service](https://wrds-web.wharton.upenn.edu/wrds/ds/comscore/index.cfm?).) Given the file sizes, the data sets are posted on Harvard DVN.

* [2004 data]()

#### Application

In [Ideological Segregation Online and Offline](http://www.nber.org/papers/w15916) (by Matthew Gentzkow and Jesse Shapiro), pick news domains as follows:

> To construct our universe of national political news and opinion websites, we begin with all sites that comScore categorizes as “General News” or “Politics.” We exclude sites of local newspapers and television stations, other local news and opinion sites, and sites devoted entirely to non-political topics such as sports or entertainment. We supplement this list with the sites of the 10 largest US newspapers (as defined by the Audit Bureau of Circulations for the first half of 2009).
We also add all domains that appear on any of thirteen online lists of political news and opinion websites. The final list includes 1,379 sites.

#### License

Released under the [MIT License](License.md)


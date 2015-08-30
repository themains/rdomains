### Domain Classifier

Be it understanding media consumption, or segmenting domain referrals, we need to classify the content hosted on domains. 

When faced with the task, often enough, researchers resort to heuristic solutions. For instance, 

> We select an initial universe of news outlets (i.e., web domains) via the Open Directory Project (ODP, dmoz.org), a collective of tens of thousands of editors who hand-label websites into a classification hierarchy. This gives 7,923 distinct domains labeled as: news, politics/news, politics/media, and regional/news. Since the vast majority of these news sites receive relatively little traffic, to simplify our analysis we restrict to the one hundred domains that attracted the largest number of unique visitors from our sample of toolbar users. This list of popular news sites includes every major national news source, well-known blogs and many regional dailies, and collectively accounts for over 98% of page views of news sites in the full ODP list (as estimated via our toolbar sample). The complete list of 100 domains is given in the Appendix.

[Filter Bubbles, Echo Chambers, and Online News Consumption](https://5harad.com/papers/bubbles.pdf)

The solution is reasonable but unsatisfactory. For instance, we don't know the number of false positives and negatives. 

There are two simple ways to improve on such methods. One is to build a calibrated keyword classifier. Start with keywords that are good at picking domains with particular content. And then improve and calibrate it using an API. See for instance, [Where's the Porn? Classifying Porn Domains Using a Calibrated Keyword Classifier](http://gbytes.gsood.com/2015/07/23/wheres-the-porn-classifying-porn-domains-using-a-calibrated-keyword-classifier/). Or one may simply rely on APIs. See for instance, [Where's the news?: Classifying News Domains](http://gbytes.gsood.com/2015/07/23/wheres-the-news-classifying-news-domains/) for a discussion of the method and some remaining issues. 

Relying on APIs is of course not optimal. For one, we don't know the error they make in classifying the content of domains. So to calibrate the error, one may want to handcode a large random sample of domains and report the confusion matrix. Or better yet perhaps, one may want to devise own algorithm to categorize domains. Both are easy enough to do but need some doing. For now, APIs. 

There are a variety of APIs in the market that provide off-the-shelf solutions for categorizing the content hosted on different domains. Prominent among them are: [Zvelvo](https://zvelo.com/), [Similar Web](https://developer.similarweb.com/website_categorization_API), [DatumBox](http://www.datumbox.com/machine-learning-api/), [Fortiguard](http://www.fortiguard.com/static/webfiltering.html) and [Trusted Source](http://www.trustedsource.org/en/feedback/url).

Of these, we pick [Trusted Source](http://www.trustedsource.org/en/feedback/url) because it is free. (The script for categorizing domains using the Trusted Source API is provided below.) We apply the script to 2004 comScore browsing data, producing a file that contains unique domains and the content category output by the API. 

#### Script

The script [api_domain_classifier](api_domain_classifier.py) takes a csv with a column of domain names ([sample input](sample_in.csv)) and appends a column containing the content category according to [Trusted Source](http://www.trustedsource.org/en/feedback/url) ([sample output](sample_out.csv)). (Note that the script is larger than a conventional API script because Trusted Source returns HTML webpage in response to requests.) The script is very modestly tailored towards large files in the following manner: If you have a large input file, you would ideally want to split the file and run multiple scripts in parallel across potentially different servers. To ease collation of the final data, the script defaults to an output file name that tracks what portion of the file is being processed of the whole. So the output file for 1 of 8 parts will be named `url_category_part_1_8` by default. The two command line arguments `current_part`, and `total_parts` are **neccessary**. For cases where file hasn't been split, just pass 1 1. For example:
```
python api_domain_classifier.py 1 1  
```
Other than the neccessary command line options, following options (within the script) can be tweaked:  
* INPUT_FILE: Path to the Input file (Line 7)
* URL_COLUMN_NAME: name of the url column (Line 8)
* URL_CATEGORY_COLUMN_NAME: name of the url_catefoty column name in outputfile (Line 9)
* FINAL_OUTPUT_FILE: name of the final output file (Line 22)

##### Misc. Notes

* Splitting Files
	* Unix: `split -l 500 myfile segment` (Splits into 500 line chunks.)

* Merging multiple csv files into one big file.
	* On Windows: `copy *.csv combined.csv`
	* On Unix: `cat *csv > all.csv`

#### Data

comScore provides content category for some domains. For instance, in [Ideological Segregation Online and Offline](http://www.nber.org/papers/w15916) (by Matthew Gentzkow and Jesse Shapiro), note:

> To construct our universe of national political news and opinion websites, we begin with all sites that comScore categorizes as “General News” or “Politics.” We exclude sites of local newspapers and television stations, other local news and opinion sites, and sites devoted entirely to non-political topics such as sports or entertainment. We supplement this list with the sites of the 10 largest US newspapers (as defined by the Audit Bureau of Circulations for the first half of 2009). We also add all domains that appear on any of thirteen online lists of political news and opinion websites. The final list includes 1,379 sites.

However, as they note, the list is a bit incomplete. And the use of thirteen online lists seems somewhat adhoc. In light of that, and to make it easier for researchers to exploit the comScore data, we provide categories for all unique domains in the 2004 comScore dataset. (Academic users can access the comScore browsing data from the [Wharton Research Data Service](https://wrds-web.wharton.upenn.edu/wrds/ds/comscore/index.cfm?).) Given the file size, the data set is posted on Harvard DVN.

* [2004 data](http://dx.doi.org/10.7910/DVN/BPS1OK)

#### License

Released under the [MIT License](License.md)


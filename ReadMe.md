## Domain Classifier

Be it understanding media consumption, or segmenting domain referrals, we need to classify the content hosted on domains. 

When faced with the task, often enough, researchers resort to heuristic solutions. For instance, 

> We select an initial universe of news outlets (i.e., web domains) via the Open Directory Project (ODP, dmoz.org), a collective of tens of thousands of editors who hand-label websites into a classification hierarchy. This gives 7,923 distinct domains labeled as: news, politics/news, politics/media, and regional/news. Since the vast majority of these news sites receive relatively little traffic, to simplify our analysis we restrict to the one hundred domains that attracted the largest number of unique visitors from our sample of toolbar users. This list of popular news sites includes every major national news source, well-known blogs and many regional dailies, and collectively accounts for over 98% of page views of news sites in the full ODP list (as estimated via our toolbar sample). The complete list of 100 domains is given in the Appendix.

[Filter Bubbles, Echo Chambers, and Online News Consumption](https://5harad.com/papers/bubbles.pdf)

The solution is reasonable but unsatisfactory. For instance, we don't know the number of false positives and negatives. 

There are two simple ways to improve on such methods. One is to build a calibrated keyword classifier. Start with keywords that are good at picking domains with particular content. And then improve and calibrate it using an API. See for instance, [Where's the Porn? Classifying Porn Domains Using a Calibrated Keyword Classifier](http://gbytes.gsood.com/2015/07/23/wheres-the-porn-classifying-porn-domains-using-a-calibrated-keyword-classifier/). Or one may simply rely on APIs. See for instance, [Where's the news?: Classifying News Domains](http://gbytes.gsood.com/2015/07/23/wheres-the-news-classifying-news-domains/) for a discussion of the method and some remaining issues. 

Relying on APIs is of course not optimal. For one, we don't know the error they make in classifying the content of domains. So to calibrate the error, one may want to handcode a large random sample of domains and report the confusion matrix. Or better yet perhaps, one may want to devise own algorithm to categorize domains. Both are easy enough to do but need some doing. 

### Scripts

* [API Domain Classifier](trusted/) (Python)
* [Domain Name Based Classifier](domain_name/) (R)
* [rdomains: R package providing access to both API and ML](rdomains/) (R)

### License

Released under the [MIT License](https://opensource.org/licenses/MIT)

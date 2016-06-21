import time
import urllib2
import requests
import os
import sys

INPUT_FILE = "sample_in.csv"
URL_COLUMN_NAME = "url"
URL_CATEGORY_COLUMN_NAME = "url_class"
CLASSIFIER_API = "http://www.trustedsource.org/en/feedback/url"

CURRENT_PART = 1
ALL_PART = 1

# Get the parameters from command
if len(sys.argv)!=3:
    print "If the input file has been split, enter the current part and the total number of parts."
    exit()
else:
    CURRENT_PART = int(sys.argv[1])
    ALL_PART = int(sys.argv[2])
FINAL_OUTPUT_FILE = "url_category_part_{0!s}_{1!s}.csv".format(CURRENT_PART, ALL_PART)

def simplify_domain(my_str):
    """
    Get the host name. Strip http, slashes, www etc.
    """
    domain = my_str.strip()
    domain = domain.replace("http://","")
    domain = domain.replace("www.","")
    domain = domain.split("/")[0].strip()
    return domain

def delete_last_comma(my_str):
    domain = my_str.strip().replace("\n","")
    if my_str[-1:]==",":
        my_str = my_str[:-1]
    return my_str

###############################Read the input domains#####################################

def find_with_pattern(my_str, startPattern, endPattern):
    """
    Find the string that starts with <startPattern> and ends with <endPattern> in the orginal string <my_str>.
    Args:
        + my_str: orginal string.
        + startPattern: 
        + endPattern: 
    Returns:
        + The found string,
        + and the remained part of the orginal string.
    """
    x = my_str.find(startPattern)
    if x==-1:
        return "",my_str
    my_str = my_str[x + len(startPattern):]
    y = my_str.find(endPattern)
    if y==-1:
        return "",my_str
    return my_str[:y], my_str[y+len(endPattern):]

print "   Start processing the data file {0!s}".format(INPUT_FILE)
FILE_DATA = []
first_line = True
INPUT_DOMAIN_INDEX = -1
with open(INPUT_FILE) as myfile:
        for line in myfile:
                line = line.replace("\n","").strip()
                if len(line)==0:
                    continue
                if first_line:
                    INPUT_HEADER = line
                    items = line.split(",")
                    
                    for i, v in enumerate(items):
                        if v.strip()==URL_COLUMN_NAME:
                            INPUT_DOMAIN_INDEX = i
                            break;
                    first_line = False
                    if INPUT_DOMAIN_INDEX==-1:
                        break;
                else:
                    FILE_DATA.append(line)
            
start_line = len(FILE_DATA)/ALL_PART*(CURRENT_PART-1)
end_line = len(FILE_DATA)/ALL_PART*CURRENT_PART
if end_line>len(FILE_DATA):
    end_line = len(FILE_DATA)
if start_line<0:
    start_line = 0
FILE_DATA = FILE_DATA[start_line:end_line]

# Load the classified domains
my_output_file = open(FINAL_OUTPUT_FILE,"ab+")
OUTPUT_CATEGORY_INDEX = -1
OUTPUT_DOMAIN_INDEX = -1
first_line = True
CATEGORY_URL = {}
for line in my_output_file:
    line = line.replace("\n","").strip()
    if len(line)==0:
        continue
    if first_line:
                    OUTPUT_HEADER = line
                    items = line.split(",")
                    OUTPUT_CATEGORY_INDEX = -1
                    for i, v in enumerate(items):
                        if v.strip()==URL_COLUMN_NAME:
                            OUTPUT_DOMAIN_INDEX = i
                            break;
                    for i, v in enumerate(items):
                        if v.strip()==URL_CATEGORY_COLUMN_NAME:
                            OUTPUT_CATEGORY_INDEX = i
                            break;
                    first_line = False
                    if OUTPUT_DOMAIN_INDEX==-1 or OUTPUT_CATEGORY_INDEX==-1 :
                        break
    else:
                    domain = simplify_domain(line.split(",")[OUTPUT_DOMAIN_INDEX])
                    category = simplify_domain(line.split(",")[OUTPUT_CATEGORY_INDEX])
                    CATEGORY_URL[domain] = category
    

# Write file the first time
if OUTPUT_DOMAIN_INDEX==-1 or OUTPUT_CATEGORY_INDEX==-1:
    my_output_file = open(FINAL_OUTPUT_FILE,"w")
    my_output_file.write(delete_last_comma(INPUT_HEADER)+","+URL_CATEGORY_COLUMN_NAME+"\n")
    my_output_file.close()
    my_output_file = open(FINAL_OUTPUT_FILE,"ab+")

# Cassify new domains
count = 0
prev_timer= time.time()
for line in FILE_DATA:
        domain = simplify_domain(line.split(",")[INPUT_DOMAIN_INDEX])
        count = count + 1
        # Monitor the progress
        if (count%10==0):
            now = time.time()
            difference = int(now - prev_timer)
            print " + Processing line {0!s}0th time_till_now={1!s}(s)".format(count/10, difference)

        print "{0:d} - {1!s}".format(count, domain)

        if domain in CATEGORY_URL.keys():
            category = CATEGORY_URL[domain]
        else:
            # Query using api
            payload = {'sid': 'BB41514AA0919EFF7C97140C58DFE488', 'action': 'checksingle', 'product':'01-ts','url':domain}
            try:
                r = requests.post(CLASSIFIER_API, data=payload)
                data =  r.text
            except:
                print "CONNECTION ERROR"
                continue

            categoryDiv,tmp = find_with_pattern(data,'<b>Categorization</b>','</table>')
            items = categoryDiv.split('<td align="left" valign="top" nowrap="nowrap">')
            if len (items)>=3:
                category = items[3]
                if category.find("<br")>-1:
                            category = category[:category.find("<br")]
                if category.find("- ")==0:
                            category = category[2:]
                if category.find("</td>")>-1:
                            category = category[:category.find("</td>")]
                if len(category)==0:
                            category = "UNKNOWN"
            else:
                        category = "UNKNOWN"
            print category
            CATEGORY_URL[domain] = category
            my_output_file.write("{0!s},{1!s}\n".format(delete_last_comma(line), category))

my_output_file.close()              

#######################################DONE##############################################
print "Done, write the final output into file {0!s}".format(FINAL_OUTPUT_FILE)

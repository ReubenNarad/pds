import csv
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import pandas as pd
from sklearn.cluster import KMeans

CPLEX_DATA_PATH = "../cplex/data"
RANDOM_SEED = 1

# Load consumption data
data = pd.read_csv('../data/consumption.csv')
data_staples = pd.read_csv('../data/consumption_staples.csv')

# Weight latitude and longitude
GEO_WEIGHT = .0001 # Higher value prioritizes geographic proximity over taste similarity
data[['Latitude', 'Longitude']] *= GEO_WEIGHT

# Perform K-means clustering on districts by past consumption and geography
kmeans = KMeans(n_clusters=5, n_init=30, random_state=RANDOM_SEED)
y = kmeans.fit_predict(data.drop(columns=['District', 'Median Income', 'Households']))
data['Cluster'] = y

# Find total population per cluster
households = data.groupby('Cluster')['Households'].sum()

# Split dataframe by crop type (pulse or grain)
grains = ['jowar','bajra','barley','maize','small millets','ragi']
pulses = ['arhar','moong','masur','urd','peas','khesari','gram products','besan','other pulse products','other pulses']

data_pulses = data.drop(columns=grains+['District', 'Median Income', 'Latitude', 'Longitude', 'Households'])
data_grains = data.drop(columns=pulses+['District', 'Median Income', 'Latitude', 'Longitude', 'Households'])

# Group by cluster and calculate median for each food item
pulses_summary = data_pulses.groupby('Cluster').median()
grains_summary = data_grains.groupby('Cluster').median()

# Convert cluster medians to preferences with softmax
def softmax(x):
    e_x = np.exp(x - np.max(x))
    return e_x / e_x.sum(axis=0)

pulses_softmax = pulses_summary.apply(softmax, axis=1)
grains_softmax = grains_summary.apply(softmax, axis=1)

# Combine pulse and grain dataframes
combined = pd.concat([grains_softmax, pulses_softmax], axis=1)
combined.insert(0, 'Households', households)

# Extract staple srop preferences
data_staples['rice_proportion'] = data_staples['rice-om'] / (data_staples['rice-om'] + data_staples['wheat-om'])
data['Staple'] = data_staples['rice_proportion'].apply(
    lambda x: 'Rice' if x > 0.66 else ('Mix' if 0.33 < x < 0.66 else 'Wheat')
)

# Save outputs in cplex data directory
combined.to_csv(CPLEX_DATA_PATH + "/cluster_preferences.csv")
data[['District', 'Households', 'Cluster', 'Staple']].to_csv(CPLEX_DATA_PATH + '/clusters.csv', index=False)


### CREATE FIGURES

POSTPROCESS_PATH = '../postprocess/figs/'

# Cluster Map
plt.figure(figsize=(6, 12))
cmap = plt.get_cmap("Set1")
num_clusters = data['Cluster'].nunique()
colors = cmap(np.linspace(0, 1, num_clusters))
plt.scatter(data['Latitude']/GEO_WEIGHT, data['Longitude']/GEO_WEIGHT, c=data['Cluster'], cmap=cmap, alpha=0.7)
plt.gca().invert_yaxis()
plt.gca().invert_xaxis()
plt.title(f"KMeans Clusters, Geographic Weight: {GEO_WEIGHT}", size=18)
plt.xlabel("Longitude", size=14)
plt.ylabel("Latitude", size=14)
plt.axis("equal")
cluster_labels = np.unique(data['Cluster'])
handles = [plt.Line2D([0], [0], marker='o', color='w', markerfacecolor=c, markersize=10) for c in colors]
plt.legend(handles, cluster_labels, title="Clusters")

plt.savefig(POSTPROCESS_PATH + 'cluster_map.png')

# Staple Preferences Map
plt.figure(figsize=(6, 12))
color_map = {'Rice': 'olive', 'Mix': 'chocolate', 'Wheat': 'gold'}
colors = data['Staple'].map(color_map)
scatter = plt.scatter(data['Latitude']/GEO_WEIGHT, data['Longitude']/GEO_WEIGHT, c=colors, alpha=0.7)
plt.gca().invert_yaxis()
plt.gca().invert_xaxis()
plt.title(f"Staple Crop Preference", size=18)
plt.xlabel("Longitude", size=14)
plt.ylabel("Latitude", size=14)
plt.axis("equal")
labels = ['Rice', 'Mix', 'Wheat']
legend_handles = [plt.Line2D([], [], color=color_map[labels[i]], marker='o', linestyle='None', markersize=10, label=labels[i]) for i in range(len(labels))]
plt.legend(handles=legend_handles)

plt.savefig(POSTPROCESS_PATH + 'staple_preference.png')

# Crop Preferences Plot
combined.drop(columns='Households').plot(kind='bar', figsize=(20,10))
plt.title('Relative crop preferences by cluster')
plt.ylabel('Preference')
plt.xlabel('Cluster')
plt.savefig(POSTPROCESS_PATH + 'preferences.png')
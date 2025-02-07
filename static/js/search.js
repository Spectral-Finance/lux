document.addEventListener('DOMContentLoaded', function() {
    const searchInput = document.getElementById('searchInput');
    const searchButton = document.getElementById('searchButton');
    const loadingSpinner = document.getElementById('loadingSpinner');
    const errorAlert = document.getElementById('errorAlert');
    const resultsContainer = document.getElementById('resultsContainer');

    searchButton.addEventListener('click', performSearch);
    searchInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            performSearch();
        }
    });

    function performSearch() {
        const query = searchInput.value.trim();
        
        if (!query) {
            showError('Please enter a search term');
            return;
        }

        // Show loading state
        loadingSpinner.classList.remove('d-none');
        errorAlert.classList.add('d-none');
        resultsContainer.innerHTML = '';

        fetch(`/search?q=${encodeURIComponent(query)}`)
            .then(response => response.json())
            .then(data => {
                loadingSpinner.classList.add('d-none');
                
                if (data.error) {
                    showError(data.error);
                    return;
                }

                displayResults(data.tweets);
            })
            .catch(error => {
                loadingSpinner.classList.add('d-none');
                showError('An error occurred while fetching results');
                console.error('Error:', error);
            });
    }

    function showError(message) {
        errorAlert.textContent = message;
        errorAlert.classList.remove('d-none');
    }

    function displayResults(tweets) {
        if (!tweets || tweets.length === 0) {
            resultsContainer.innerHTML = `
                <div class="alert alert-info">
                    No tweets found for this search term.
                </div>`;
            return;
        }

        const tweetsHTML = tweets.map(tweet => `
            <div class="card mb-3">
                <div class="card-body">
                    <div class="d-flex align-items-start mb-2">
                        <img src="${tweet.user.profile_image}" 
                             alt="${tweet.user.name}" 
                             class="rounded-circle me-2" 
                             width="48" height="48">
                        <div>
                            <h6 class="mb-0">${tweet.user.name}</h6>
                            <small class="text-muted">@${tweet.user.screen_name}</small>
                        </div>
                    </div>
                    <p class="card-text">${tweet.text}</p>
                    <div class="d-flex justify-content-between text-muted">
                        <small>${tweet.created_at}</small>
                        <div>
                            <span class="me-3">
                                <i class="bi bi-heart"></i> ${tweet.favorite_count}
                            </span>
                            <span>
                                <i class="bi bi-repeat"></i> ${tweet.retweet_count}
                            </span>
                        </div>
                    </div>
                </div>
            </div>
        `).join('');

        resultsContainer.innerHTML = tweetsHTML;
    }
});

document.getElementById('searchForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const keyword = document.getElementById('keyword').value;
    const resultsDiv = document.getElementById('results');
    
    resultsDiv.innerHTML = '<div class="text-center"><div class="spinner-border" role="status"></div></div>';
    
    try {
        const response = await fetch('/search', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: `keyword=${encodeURIComponent(keyword)}`
        });
        
        const data = await response.json();
        
        if (response.ok) {
            if (data.tweets && data.tweets.length > 0) {
                resultsDiv.innerHTML = data.tweets.map(tweet => `
                    <div class="tweet-card">
                        <div class="tweet-user">@${tweet.user}</div>
                        <div class="tweet-text">${tweet.text}</div>
                        <div class="tweet-date">${new Date(tweet.created_at).toLocaleDateString()}</div>
                    </div>
                `).join('');
            } else {
                resultsDiv.innerHTML = '<div class="alert alert-info">No tweets found for this keyword.</div>';
            }
        } else {
            resultsDiv.innerHTML = `<div class="alert alert-danger">${data.error || 'An error occurred'}</div>`;
        }
    } catch (error) {
        resultsDiv.innerHTML = '<div class="alert alert-danger">Failed to search tweets. Please try again.</div>';
    }
});

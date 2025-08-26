import { test, expect } from '@playwright/test';

test.describe('IMPACT Genealogy - Live Demo Tests', () => {
  
  test('Verify Member Genealogy UI Elements', async ({ page }) => {
    await page.goto('http://localhost:8083/genealogy-test/member.html');
    
    // Wait for page load
    await page.waitForLoadState('domcontentloaded');
    
    // Take screenshot
    await page.screenshot({ path: 'docs/screens/test-member-ui.png', fullPage: true });
    
    // Basic element verification
    const title = await page.locator('h2').textContent();
    console.log('Page title:', title);
    
    const tabCount = await page.locator('.tab').count();
    console.log('Phase tabs found:', tabCount);
    
    expect(tabCount).toBeGreaterThan(0);
  });

  test('Verify Leader Console UI Elements', async ({ page }) => {
    await page.goto('http://localhost:8083/genealogy-test/leader.html');
    
    // Wait for page load
    await page.waitForLoadState('domcontentloaded');
    
    // Take screenshot
    await page.screenshot({ path: 'docs/screens/test-leader-ui.png', fullPage: true });
    
    // Verify KPI cards
    const kpiCards = await page.locator('.card').count();
    console.log('KPI cards found:', kpiCards);
    
    expect(kpiCards).toBeGreaterThan(0);
  });

  test('Test API Mock Functionality', async ({ page }) => {
    // Mock API response
    await page.route('**/api/genealogy/**', async route => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          phase: 1,
          root: 200,
          tree: {
            member: { member_id: 200, name: "Test User", points: 100 },
            directs: [
              { member: { member_id: 301, name: "Direct 1" } }
            ]
          }
        })
      });
    });

    const response = await page.request.get('/api/genealogy/1?root=200');
    expect(response.status()).toBe(200);
    
    const data = await response.json();
    expect(data.tree.member.member_id).toBe(200);
    
    console.log('API mock test passed');
  });
});
